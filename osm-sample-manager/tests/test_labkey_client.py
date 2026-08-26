"""Client behaviour, exercised against a stub transport rather than the network.

Every test here corresponds to a sharp edge of the LabKey API that has already
cost time once: redirects that loop, 4xx bodies that get discarded, HTTP 200
responses that report failure, and action names that do not exist.
"""
from __future__ import annotations

import json
import logging

import pytest
import requests

from osm.labkey.client import (
    CSRF_HEADER,
    LabKeyAuthError,
    LabKeyClient,
    LabKeyError,
    _encode_container,
    _redact,
)
from osm.labkey.config import LabKeyConfig


class StubResponse:
    """Just enough of ``requests.Response`` for the client's code paths."""

    def __init__(self, status: int = 200, body: object = None, *, text: str | None = None,
                 headers: dict | None = None, url: str = "https://stub/x"):
        self.status_code = status
        self.headers = headers or {"Content-Type": "application/json"}
        self.url = url
        if text is not None:
            self.text = text
        else:
            self.text = json.dumps(body if body is not None else {"success": True})
        self.content = self.text.encode()

    def json(self):
        return json.loads(self.text)


class StubSession:
    """Records calls and replays queued responses in order."""

    def __init__(self, responses=None):
        self.responses = list(responses or [])
        self.calls: list[dict] = []
        self.headers: dict[str, str] = {}
        self.cookies = requests.cookies.RequestsCookieJar()
        self.verify = True
        self.closed = False

    def _next(self, method, url, kwargs):
        self.calls.append({"method": method, "url": url, **kwargs})
        if not self.responses:
            return StubResponse()
        item = self.responses.pop(0)
        if isinstance(item, Exception):
            raise item
        return item

    def get(self, url, **kw):
        return self._next("GET", url, kw)

    def post(self, url, **kw):
        return self._next("POST", url, kw)

    def request(self, method, url, **kw):
        return self._next(method, url, kw)

    def close(self):
        self.closed = True


def make_client(responses=None, **cfg_kw) -> tuple[LabKeyClient, StubSession]:
    cfg = LabKeyConfig(url="https://lk.test", api_key="k" * 8, verify_tls=False, **cfg_kw)
    session = StubSession(responses)
    return LabKeyClient(cfg, session=session), session


WHOAMI = StubResponse(200, {"success": True, "email": "someone@example.test",
                            "CSRF": "csrf-token-value"})


# --- session bootstrap -------------------------------------------------------

def test_connect_probes_whoami_and_captures_csrf():
    client, session = make_client([WHOAMI])
    client.connect()
    assert client.base_url == "https://lk.test"
    assert client.csrf == "csrf-token-value"
    assert session.headers[CSRF_HEADER] == "csrf-token-value"
    assert client.user_email == "someone@example.test"


def test_connect_falls_through_to_the_labkey_context_path():
    """A WAR deployment serves under /labkey. Probing avoids 404 on every call."""
    client, _ = make_client([StubResponse(404, text="not found"), WHOAMI])
    client.connect()
    assert client.base_url == "https://lk.test/labkey"


def test_connect_treats_an_html_response_as_the_wrong_context():
    """A login page means the API is not here, even though the status is 200."""
    client, _ = make_client([
        StubResponse(200, text="<html>login</html>", headers={"Content-Type": "text/html"}),
        WHOAMI,
    ])
    client.connect()
    assert client.base_url == "https://lk.test/labkey"


def test_connect_reports_every_candidate_when_all_fail():
    client, _ = make_client([StubResponse(500, text="boom"), StubResponse(404, text="nope")])
    with pytest.raises(LabKeyError) as excinfo:
        client.connect()
    message = str(excinfo.value)
    assert "https://lk.test" in message
    assert "500" in message and "404" in message


def test_connect_is_idempotent():
    client, session = make_client([WHOAMI])
    client.connect()
    client.connect()
    assert len(session.calls) == 1


def test_identity_is_absorbed_from_the_nested_user_object():
    """login-loginApi.api nests the principal under `user`, unlike whoAmI."""
    cfg = LabKeyConfig(url="https://lk.test", user="someone", password="pw", verify_tls=False)
    session = StubSession([
        StubResponse(200, {"success": True, "CSRF": "t"}),
        StubResponse(200, {"success": True, "CSRF": "t2",
                           "user": {"email": "someone@example.test", "id": 1004}}),
    ])
    client = LabKeyClient(cfg, session=session)
    client.connect()
    assert client.user_email == "someone@example.test"


def test_password_login_uses_email_not_username():
    """LabKey's parameter is `email`. Getting this wrong fails confusingly."""
    cfg = LabKeyConfig(url="https://lk.test", user="someone", password="pw", verify_tls=False)
    session = StubSession([
        StubResponse(200, {"success": True, "CSRF": "t"}),
        StubResponse(200, {"success": True, "CSRF": "t2", "email": "someone@example.test"}),
    ])
    LabKeyClient(cfg, session=session).connect()
    login = session.calls[1]
    assert login["url"].endswith("/login-loginApi.api")
    assert set(login["data"]) == {"email", "password"}


def test_a_rejected_login_raises_an_auth_error_without_echoing_the_password():
    """LabKey can reflect submitted form values on failure; the message must not
    carry them through."""
    cfg = LabKeyConfig(url="https://lk.test", user="someone",
                       password="super-secret-value", verify_tls=False)
    session = StubSession([
        StubResponse(200, {"success": True, "CSRF": "t"}),
        StubResponse(401, {"success": False, "exception": "wrong password",
                           "submitted": {"password": "super-secret-value"}}),
    ])
    with pytest.raises(LabKeyAuthError) as excinfo:
        LabKeyClient(cfg, session=session).connect()
    assert "super-secret-value" not in str(excinfo.value)


# --- transport policy --------------------------------------------------------

def test_redirects_are_never_followed():
    """importFolder.post redirects towards a hostname the self-signed
    certificate does not cover; following it loops."""
    client, session = make_client([WHOAMI, StubResponse()])
    client.connect()
    client.get_json("project-getContainers.api")
    for call in session.calls:
        assert call["allow_redirects"] is False


def test_an_unexpected_redirect_is_surfaced_rather_than_followed():
    client, _ = make_client([
        WHOAMI,
        StubResponse(302, text="", headers={"Location": "https://elsewhere/x"}),
    ])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.get_json("admin-importFolder.post")
    assert "redirect" in str(excinfo.value).lower()
    assert "https://elsewhere/x" in str(excinfo.value)


def test_tls_verification_setting_reaches_the_session():
    _, session = make_client()
    assert session.verify is False


def test_a_transport_failure_becomes_a_labkey_error():
    client, _ = make_client([WHOAMI, requests.ConnectionError("refused")])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.get_json("project-getContainers.api")
    assert excinfo.value.status is None
    assert "ConnectionError" in str(excinfo.value)


# --- error surfacing ---------------------------------------------------------

def test_a_4xx_body_is_preserved_on_the_error():
    """Spec §16.2 requires the response body to be stored on a failed publish,
    so it must survive rather than being consumed by a raise-for-status."""
    client, _ = make_client([WHOAMI, StubResponse(
        400, {"success": False, "exception": "Domain already exists",
              "exceptionClass": "org.labkey.api.view.NotFoundException"})])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.post_json("property-createDomain.api", {})
    err = excinfo.value
    assert err.status == 400
    assert "Domain already exists" in err.body
    assert err.action == "property-createDomain.api"
    assert err.exception_class == "org.labkey.api.view.NotFoundException"


def test_http_200_with_success_false_is_still_a_failure():
    """The trap: LabKey reports failure in the body while answering 200."""
    client, _ = make_client([WHOAMI, StubResponse(
        200, {"success": False, "exception": "no such query"})])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.post_json("query-selectRows.api", {})
    assert excinfo.value.status == 200
    assert "no such query" in str(excinfo.value)


def test_an_exception_field_alone_is_a_failure():
    client, _ = make_client([WHOAMI, StubResponse(200, {"exception": "Could not find domain"})])
    client.connect()
    with pytest.raises(LabKeyError):
        client.post_json("property-getDomainDetails.api", {})


@pytest.mark.parametrize("status", [401, 403])
def test_authorisation_failures_raise_the_auth_subclass(status):
    client, _ = make_client([WHOAMI, StubResponse(status, {"success": False,
                                                           "exception": "denied"})])
    client.connect()
    with pytest.raises(LabKeyAuthError):
        client.get_json("query-selectRows.api")


def test_an_html_response_explains_the_likely_cause():
    """A wrong action name makes LabKey serve a page, not JSON. The message
    should say so instead of raising a bare JSON decode error."""
    client, _ = make_client([WHOAMI, StubResponse(
        200, text="<html>Page Not Found</html>", headers={"Content-Type": "text/html"})])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.get_json("query-madeUpAction.api")
    assert "action name" in str(excinfo.value)


def test_a_long_body_is_truncated_in_the_message_but_kept_in_full_on_the_error():
    client, _ = make_client([WHOAMI, StubResponse(500, text="x" * 5000,
                                                  headers={"Content-Type": "text/plain"})])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.get_json("query-selectRows.api")
    assert len(str(excinfo.value)) < 1000
    assert len(excinfo.value.body) == 5000


# --- known-bad action names --------------------------------------------------

@pytest.mark.parametrize(
    "action, hint",
    [
        ("query-importData.api", "query-import.api"),
        ("experiment-saveMaterials.api", "experiment-importSamples.api"),
        ("experiment-deriveSamples.api", "experiment-derive.api"),
    ],
)
def test_actions_that_do_not_exist_fail_locally_with_the_correct_name(action, hint):
    """Verified by source inspection (memory RF-009, V-015). Catching these here
    turns a confusing 404 into an actionable message."""
    client, _ = make_client([WHOAMI])
    client.connect()
    with pytest.raises(LabKeyError) as excinfo:
        client.post_json(action, {})
    assert hint in str(excinfo.value)


# --- idempotency support -----------------------------------------------------

def test_a_tolerated_substring_turns_a_failure_into_success():
    """Creating something that already exists is success, per the LabKey
    HTTP conventions standard."""
    client, _ = make_client([WHOAMI, StubResponse(
        400, {"success": False, "exception": "A domain with that name already exists"})])
    client.connect()
    result = client.post_json("property-createDomain.api", {}, tolerate=["already exists"])
    assert result["success"] is False  # the body is returned unchanged, not rewritten


def test_an_untolerated_failure_still_raises():
    client, _ = make_client([WHOAMI, StubResponse(
        400, {"success": False, "exception": "permission denied"})])
    client.connect()
    with pytest.raises(LabKeyError):
        client.post_json("property-createDomain.api", {}, tolerate=["already exists"])


# --- CSRF --------------------------------------------------------------------

def test_multipart_posts_carry_the_csrf_token_as_a_field_as_well():
    client, session = make_client([WHOAMI, StubResponse()])
    client.connect()
    client.call("POST", "query-import.api", files={"file": ("a.csv", b"x")})
    assert session.calls[-1]["data"][CSRF_HEADER] == "csrf-token-value"


def test_a_missing_csrf_token_warns_rather_than_failing_silently(caplog):
    client, _ = make_client([StubResponse(200, {"success": True, "email": "x@y.test"})])
    with caplog.at_level(logging.WARNING, logger="osm.labkey"):
        client.connect()
    assert any("CSRF" in r.message for r in caplog.records)


# --- URL construction --------------------------------------------------------

@pytest.mark.parametrize(
    "path, expected",
    [
        ("", ""),
        ("/", ""),
        ("/home", "home"),
        ("home", "home"),
        ("/Tutorials/HIV Study", "Tutorials/HIV%20Study"),
        ("/a b/c+d", "a%20b/c%2Bd"),
    ],
)
def test_container_paths_are_encoded_but_keep_their_separators(path, expected):
    assert _encode_container(path) == expected


def test_url_for_composes_base_container_and_action():
    client, _ = make_client([WHOAMI])
    client.connect()
    assert client.url_for("query-selectRows.api", "/Tutorials/HIV Study") == (
        "https://lk.test/Tutorials/HIV%20Study/query-selectRows.api")


def test_calling_before_connect_is_refused():
    client, _ = make_client()
    with pytest.raises(LabKeyError) as excinfo:
        client.url_for("query-selectRows.api")
    assert "not connected" in str(excinfo.value)


# --- redaction ---------------------------------------------------------------

#: A value that must never survive redaction. Distinct from any key name, so
#: the assertion tests the value and not the field label (labels are not
#: sensitive; the values under them are).
SENTINEL = "MUST-NOT-APPEAR-4f2a"


@pytest.mark.parametrize(
    "payload",
    [
        {"password": SENTINEL},
        {"apikey": SENTINEL},
        {"api_key": SENTINEL},
        {"token": SENTINEL},
        {"Password": SENTINEL},
        {"nested": {"secret": SENTINEL}},
        {"list": [{"X-LABKEY-CSRF": SENTINEL}]},
        {"Crypt": SENTINEL},
        {"outer": {"inner": [{"jdbcPassword": SENTINEL}]}},
    ],
)
def test_redaction_blanks_anything_credential_shaped(payload):
    assert SENTINEL not in json.dumps(_redact(payload))


def test_redaction_leaves_ordinary_values_alone():
    assert _redact({"schemaName": "exp", "maxRows": 10}) == {"schemaName": "exp", "maxRows": 10}


def test_debug_logging_does_not_disclose_a_password(caplog):
    client, _ = make_client([WHOAMI, StubResponse()])
    client.connect()
    with caplog.at_level(logging.DEBUG, logger="osm.labkey"):
        client.post_json("query-selectRows.api", {"password": "must-not-appear"})
    assert "must-not-appear" not in caplog.text


# --- lifecycle ---------------------------------------------------------------

def test_context_manager_connects_and_closes():
    cfg = LabKeyConfig(url="https://lk.test", api_key="k", verify_tls=False)
    session = StubSession([WHOAMI])
    with LabKeyClient(cfg, session=session) as client:
        assert client.base_url == "https://lk.test"
    assert session.closed
