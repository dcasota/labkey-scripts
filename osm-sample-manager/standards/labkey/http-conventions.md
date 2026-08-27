# Standard: talking to a LabKey server

These conventions come from the user's proven scripts
(`/root/install-labkey-*.sh`) and from verified source reading. Departing from
one needs a reason recorded in the change.

## Session

1. Bootstrap by probing `login-whoAmI.api` with a cookie jar, falling back to
   `login-loginApi.api` with `email` and `password`. The parameter is `email`,
   not `username`.
2. The CSRF token is the `X-LABKEY-CSRF` cookie value, sent as the same-named
   header on every mutating call and as a form field on multipart posts.
3. The context path may be empty or `/labkey`. Probe rather than assume.

## Transport

4. **Do not follow redirects.** Set `--max-redirs 0`. `importFolder.post`
   redirects to a host whose certificate does not match, and following it loops.
5. **Do not fail fast on 4xx.** The response body carries the reason, and it
   must reach the caller and the `FAILED` outbox row.
6. Skip TLS verification **only** for loopback hosts, because the deployment
   uses a self-signed certificate. A non-loopback host needs a valid certificate
   or an explicit opt-out.
7. Every URL is `{base}/{url-encoded container path}/{controller}-{action}`.

## Action names — verified, and easy to get wrong

8. Bulk import is **`query-import.api`**, not `query-importData.api`.
9. **`experiment-saveMaterials.api` does not exist.** Use
   `query-insertRows.api` or `query-import.api` on schema `samples`, or
   `experiment-importSamples.api`.
10. `experiment-deriveSamples` is a **view**. The programmatic endpoint is
    `experiment-derive.api`.
11. Domain actions are under the `property-` controller, which lives in the
    `experiment` module.
12. **Never call `addWebPart`.** The specification forbids it (§16) and it
    misbehaves on CE 26. Deliver portals as `folder.xml` archives.

## Idempotency

13. Treat "already exists" and "duplicate" in a response body as success.
14. Publish upserts on `osm_id`. A retry after an ambiguous timeout must
    converge, not duplicate — a response lost in transit looks exactly like a
    rejected request.
15. Check existence before creating where a probe is cheap, but never rely on
    the check alone; handle the duplicate response too, because the window
    between check and create is real.

## Credentials

16. `LK_APIKEY` takes precedence over `LK_USER` and `LK_PASSWORD`.
17. API keys are 64-character lowercase hex with **no prefix** in this build.
    `apikey` is the header name and the basic-auth username, not a value prefix.
18. `allowApiKeys` defaults to `false` on the server and must be enabled before
    a key can be minted.
