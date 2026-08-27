"""
A small, credential-safe HTTP client for the LabKey Server API.

This is the only sanctioned way for OSM code to talk to a LabKey deployment.
It exists because the LabKey API has several sharp edges that cost real time to
rediscover, each of which is handled here once:

* **Redirects must not be followed.** ``admin-importFolder.post`` answers 302
  towards the server's canonical hostname. Following that against a
  self-signed certificate bound to a different name loops until the client
  gives up. Every request sets ``allow_redirects=False``.
* **4xx bodies are the payload, not noise.** LabKey reports why a call failed
  in the response body. The spec (§16.2) requires the body to be stored on a
  failed publish, so it is preserved on :class:`LabKeyError` rather than
  discarded by a raise-for-status.
* **Success is not a status code.** LabKey answers ``200`` with
  ``{"success": false, "exception": "..."}``. Status alone is not a verdict.
* **The context path may be empty or ``/labkey``.** It is probed, not assumed.
* **Some action names differ from the obvious guess.** The import action is
  ``query-import.api``, not ``query-importData.api``;
  ``experiment-saveMaterials.api`` does not exist. See
  ``standards/labkey/http-conventions.md``.

Credentials never appear in a log line, an exception message, a URL or a
command line. See ``specs/adr/0008-credentials-exclusively-from-the-environment.md``.
"""
from __future__ import annotations

import json
import logging
from typing import Any, Mapping, Sequence
from urllib.parse import quote

import requests

from .config import LabKeyConfig, load_config

log = logging.getLogger("osm.labkey")

#: LabKey requires this header on mutating requests. Its value is the
#: same-named cookie, established during session bootstrap.
CSRF_HEADER = "X-LABKEY-CSRF"

#: Actions that are known not to exist, mapped to what to use instead. Catching
#: these locally turns a confusing 404 into an actionable message. Verified by
#: source inspection: see memory RF-009 and verification V-015.
KNOWN_BAD_ACTIONS = {
    "query-importData.api": "query-import.api",
    "experiment-saveMaterials.api": (
        "query-insertRows.api or query-import.api on schema 'samples', "
        "or experiment-importSamples.api"
    ),
    "experiment-deriveSamples.api": "experiment-derive.api",
}


class LabKeyError(Exception):
    """A LabKey call failed.

    Carries everything needed to triage without reproducing the call, which is
    what the spec's ``FAILED`` outbox row records (§16.2).
    """

    def __init__(
        self,
        action: str,
        status: int | None,
        body: str,
        *,
        url: str = "",
        exception_class: str | None = None,
    ) -> None:
        self.action = action
        self.status = status
        self.body = body
        self.url = url
        self.exception_class = exception_class
        detail = body.strip().replace("\n", " ")
        if len(detail) > 500:
            detail = detail[:500] + "…"
        super().__init__(
            f"{action} failed"
            + (f" with HTTP {status}" if status is not None else "")
            + (f" [{exception_class}]" if exception_class else "")
            + (f": {detail}" if detail else "")
        )


class LabKeyAuthError(LabKeyError):
    """Authentication or authorisation failed (401/403, or a failed login)."""


def _redact(value: object) -> object:
    """Recursively blank anything that looks like a credential.

    Applied to payloads before they reach a log line. It is deliberately broad:
    a false positive costs a masked debug value, a false negative costs a
    credential in a log file.
    """
    sensitive = ("password", "apikey", "api_key", "token", "secret", "csrf", "crypt")
    if isinstance(value, Mapping):
        return {
            k: ("***" if any(s in str(k).lower() for s in sensitive) else _redact(v))
            for k, v in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [_redact(v) for v in value]
    return value


def _encode_container(path: str) -> str:
    """URL-encode a container path, preserving the separators.

    Container paths routinely contain spaces (``/Tutorials/HIV Study``). The
    slashes are structural and must survive.
    """
    cleaned = path.strip("/")
    if not cleaned:
        return ""
    return "/".join(quote(segment, safe="") for segment in cleaned.split("/"))


class LabKeyClient:
    """A logged-in session against one LabKey server.

    Use as a context manager so the underlying connection pool is released::

        with LabKeyClient.from_env() as lk:
            lk.get_json("project-getContainers.api")
    """

    def __init__(self, config: LabKeyConfig, session: requests.Session | None = None) -> None:
        self.config = config
        self.base_url: str | None = None
        self.csrf: str | None = None
        self.user_email: str | None = None
        self._session = session or requests.Session()
        self._session.verify = config.verify_tls
        if not config.verify_tls:
            # Skipping verification is a deliberate, logged decision (loopback
            # with a self-signed certificate). urllib3 would otherwise emit an
            # InsecureRequestWarning per request, which trains readers to ignore
            # warnings. Say it once, at the level it deserves.
            log.warning("TLS verification disabled for %s", config.url)
            try:
                import urllib3

                urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
            except Exception:  # pragma: no cover - urllib3 always ships with requests
                pass
        self._session.headers.update(
            {"Accept": "application/json", "User-Agent": "OSM-LabKeyClient/1"}
        )
        self._session.headers.update(config.auth_headers())

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "LabKeyClient":
        """Build a client from the environment. Raises ``ConfigError`` if unusable."""
        return cls(load_config(env))

    def __enter__(self) -> "LabKeyClient":
        self.connect()
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    def close(self) -> None:
        self._session.close()

    # -- session bootstrap ----------------------------------------------------

    def connect(self) -> "LabKeyClient":
        """Establish a session and capture the CSRF token.

        Probes each context-path candidate with ``login-whoAmI.api``. When an
        API key is configured that call is already authenticated, so it both
        discovers the context and proves the credential. With a password, an
        unauthenticated probe still discovers the context and yields a CSRF
        token, and ``login-loginApi.api`` then authenticates.
        """
        if self.base_url is not None:
            return self

        log.info("connecting to LabKey: %s", self.config.describe())
        errors: list[str] = []
        for candidate in self.config.base_url_candidates():
            try:
                resp = self._session.get(
                    f"{candidate}/login-whoAmI.api", timeout=self.config.timeout,
                    allow_redirects=False,
                )
            except requests.RequestException as exc:
                errors.append(f"{candidate}: {type(exc).__name__}")
                continue
            if resp.status_code != 200:
                errors.append(f"{candidate}: HTTP {resp.status_code}")
                continue
            try:
                data = resp.json()
            except ValueError:
                # A login page rather than the API: wrong context path.
                errors.append(f"{candidate}: non-JSON response")
                continue
            self.base_url = candidate
            self._absorb_identity(data)
            break

        if self.base_url is None:
            raise LabKeyError(
                "login-whoAmI.api", None,
                "could not reach the LabKey API at any candidate context path: "
                + "; ".join(errors),
                url=self.config.url,
            )

        if not self.config.uses_api_key:
            self._password_login()

        if not self.csrf:
            # Mutating calls will fail without it, so surface it now rather than
            # at the first write.
            log.warning("no CSRF token captured; mutating calls will be rejected")
        log.info("LabKey session established at %s as %s", self.base_url,
                 self.user_email or "(unidentified)")
        return self

    def _absorb_identity(self, data: Mapping[str, Any]) -> None:
        """Pick up the CSRF token and the principal from any identity response.

        ``login-whoAmI.api`` reports the principal at the top level, whereas
        ``login-loginApi.api`` nests it under ``user``. Handle both, so the
        session log names who is actually connected.
        """
        csrf = data.get("CSRF") or self._session.cookies.get(CSRF_HEADER)
        if csrf:
            self.csrf = csrf
            self._session.headers[CSRF_HEADER] = csrf
        user = data.get("user")
        nested = user if isinstance(user, Mapping) else {}
        email = (data.get("email") or nested.get("email")
                 or data.get("displayName") or nested.get("displayName"))
        if email and email != "guest":
            self.user_email = email

    def _password_login(self) -> None:
        """Authenticate with LK_USER and LK_PASSWORD.

        The parameter is ``email``, not ``username`` — a detail that costs an
        afternoon to rediscover. Verified live: see memory V-006.
        """
        assert self.base_url is not None
        url = f"{self.base_url}/login-loginApi.api"
        try:
            resp = self._session.post(
                url,
                data={"email": self.config.user, "password": self.config.password},
                timeout=self.config.timeout,
                allow_redirects=False,
            )
        except requests.RequestException as exc:
            raise LabKeyError("login-loginApi.api", None,
                              f"request failed: {type(exc).__name__}", url=url) from exc

        body = resp.text
        try:
            data = resp.json()
        except ValueError:
            data = {}

        if resp.status_code != 200 or data.get("success") is False:
            # Do not echo the body wholesale: on some failures LabKey reflects
            # submitted form values, which would put the password in the message.
            raise LabKeyAuthError(
                "login-loginApi.api", resp.status_code,
                str(data.get("exception") or "login rejected"),
                url=url, exception_class=data.get("exceptionClass"),
            )
        if not data:
            raise LabKeyAuthError("login-loginApi.api", resp.status_code,
                                  f"unexpected non-JSON response ({len(body)} bytes)", url=url)
        self._absorb_identity(data)

    # -- request plumbing -----------------------------------------------------

    def url_for(self, action: str, container: str = "") -> str:
        """Build ``{base}/{container}/{controller}-{action}``."""
        if self.base_url is None:
            raise LabKeyError(action, None, "client is not connected; call connect() first")
        encoded = _encode_container(container)
        return f"{self.base_url}/{encoded}/{action}" if encoded else f"{self.base_url}/{action}"

    def request(
        self,
        method: str,
        action: str,
        *,
        container: str = "",
        json_body: Any = None,
        data: Mapping[str, Any] | None = None,
        files: Mapping[str, Any] | None = None,
        params: Mapping[str, Any] | None = None,
    ) -> requests.Response:
        """Issue one request. Returns the raw response without judging it.

        Redirects are never followed, and no exception is raised for a 4xx, so
        the caller retains the body.
        """
        if action in KNOWN_BAD_ACTIONS:
            raise LabKeyError(
                action, None,
                f"{action} does not exist in LabKey; use {KNOWN_BAD_ACTIONS[action]} "
                "(see standards/labkey/http-conventions.md)",
            )
        url = self.url_for(action, container)
        kwargs: dict[str, Any] = {
            "timeout": self.config.timeout,
            "allow_redirects": False,
            "params": params,
        }
        if json_body is not None:
            kwargs["json"] = json_body
        if data is not None:
            kwargs["data"] = data
        if files is not None:
            kwargs["files"] = files
            # Multipart posts need the token as a field as well as a header.
            if self.csrf:
                kwargs.setdefault("data", {})
                if isinstance(kwargs["data"], dict):
                    kwargs["data"] = {**kwargs["data"], CSRF_HEADER: self.csrf}

        log.debug("%s %s payload=%s", method, url,
                  json.dumps(_redact(json_body or data or {}))[:400])
        try:
            resp = self._session.request(method, url, **kwargs)
        except requests.RequestException as exc:
            raise LabKeyError(action, None, f"request failed: {type(exc).__name__}: {exc}",
                              url=url) from exc
        log.debug("%s %s -> HTTP %s (%d bytes)", method, url, resp.status_code,
                  len(resp.content or b""))
        return resp

    def call(
        self,
        method: str,
        action: str,
        *,
        container: str = "",
        json_body: Any = None,
        data: Mapping[str, Any] | None = None,
        files: Mapping[str, Any] | None = None,
        params: Mapping[str, Any] | None = None,
        tolerate: Sequence[str] = (),
    ) -> dict[str, Any]:
        """Issue a request and return its parsed JSON, raising on failure.

        A call is successful only when the status is 2xx **and** the body does
        not report ``success: false`` or carry an ``exception``. Status alone is
        not a verdict: LabKey answers 200 with a failure body.

        ``tolerate`` holds lowercase substrings that mark an "error" as an
        acceptable outcome, so that idempotent creation can treat
        ``already exists`` as success (see
        ``standards/labkey/http-conventions.md`` rule 13).
        """
        resp = self.request(method, action, container=container, json_body=json_body,
                            data=data, files=files, params=params)
        body = resp.text or ""
        lowered = body.lower()
        if tolerate and any(t.lower() in lowered for t in tolerate):
            log.info("%s: tolerated response HTTP %s", action, resp.status_code)
            try:
                return resp.json() if body.strip() else {}
            except ValueError:
                return {"success": True, "tolerated": True}

        if resp.status_code in (301, 302, 303, 307, 308):
            raise LabKeyError(
                action, resp.status_code,
                f"unexpected redirect to {resp.headers.get('Location', '(no Location)')}; "
                "redirects are not followed on purpose",
                url=resp.url,
            )

        try:
            parsed = resp.json()
        except ValueError:
            if resp.status_code >= 400:
                raise LabKeyError(action, resp.status_code, body, url=resp.url) from None
            raise LabKeyError(
                action, resp.status_code,
                f"expected JSON but received {resp.headers.get('Content-Type', 'unknown')} "
                f"({len(body)} bytes); this usually means the action name is wrong "
                "and LabKey served an HTML page",
                url=resp.url,
            ) from None

        if resp.status_code in (401, 403):
            raise LabKeyAuthError(action, resp.status_code, body, url=resp.url,
                                  exception_class=parsed.get("exceptionClass"))
        if resp.status_code >= 400 or parsed.get("success") is False or parsed.get("exception"):
            raise LabKeyError(action, resp.status_code, body, url=resp.url,
                              exception_class=parsed.get("exceptionClass"))
        return parsed

    # -- convenience ----------------------------------------------------------

    def get_json(self, action: str, *, container: str = "",
                 params: Mapping[str, Any] | None = None,
                 tolerate: Sequence[str] = ()) -> dict[str, Any]:
        return self.call("GET", action, container=container, params=params, tolerate=tolerate)

    def post_json(self, action: str, payload: Any = None, *, container: str = "",
                  tolerate: Sequence[str] = ()) -> dict[str, Any]:
        return self.call("POST", action, container=container, json_body=payload,
                         tolerate=tolerate)

    def post_form(self, action: str, fields: Mapping[str, Any], *, container: str = "",
                  tolerate: Sequence[str] = ()) -> dict[str, Any]:
        return self.call("POST", action, container=container, data=fields, tolerate=tolerate)

    # -- read-only helpers used by the verification harness -------------------

    def whoami(self) -> dict[str, Any]:
        return self.get_json("login-whoAmI.api")

    def schemas(self, container: str = "/home", include_hidden: bool = True) -> list[str]:
        data = self.post_json("query-getSchemas.api", {"includeHidden": include_hidden},
                              container=container)
        return sorted(data.get("schemas", []))

    def queries(self, schema: str, container: str = "/home") -> list[str]:
        data = self.post_json("query-getQueries.api", {"schemaName": schema},
                              container=container)
        return sorted(q["name"] for q in data.get("queries", []))

    def query_details(self, schema: str, query: str,
                      container: str = "/home") -> list[dict[str, Any]]:
        data = self.post_json("query-getQueryDetails.api",
                              {"schemaName": schema, "queryName": query},
                              container=container)
        return data.get("columns", [])

    def select_rows(self, schema: str, query: str, *, container: str = "/home",
                    max_rows: int = 100,
                    columns: Sequence[str] | None = None) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {"schemaName": schema, "queryName": query,
                                   "maxRows": max_rows}
        if columns:
            payload["columns"] = list(columns)
        return self.post_json("query-selectRows.api", payload, container=container).get("rows", [])

    def containers(self, container: str = "/", depth: int = 1) -> dict[str, Any]:
        return self.get_json("project-getContainers.api", container=container,
                             params={"includeSubfolders": "true", "depth": depth})
