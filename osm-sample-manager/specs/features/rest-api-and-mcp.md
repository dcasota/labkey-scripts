# Feature Requirement Document (FRD): REST API and MCP Server

**Feature ID**: FRD-009
**Feature Name**: REST API and MCP server sharing one authorisation path
**Related PRD Requirements**: REQ-9
**Memory Requirements**: FR-008, FR-010, FR-043, FR-044, FR-064, CON-005
**Spec Sections**: §2, §10, §18
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

The user interface, external integrations and assistants are all clients of the
same API. The MCP server translates tools onto REST calls rather than reaching
into the domain, so an agent structurally cannot exceed the role it authenticates
as.

### Value Proposition

The usual shape — a UI with a privileged back door, plus a public API with its
own checks — produces two authorisation implementations and one of them is
always weaker. Making the UI an ordinary client means the checks are exercised by
every screen every day, and an agent inherits exactly the same boundary rather
than a parallel one written in a hurry.

ADR-0006 makes the MCP server a **thin adapter over REST**. That is the whole
security argument: there is no domain access to abuse, only HTTP calls that carry
the agent's own identity.

### Success Criteria

- **No privileged back door for the UI** (CON-005): every UI action is
  reproducible with `curl` and the same credentials.
- The MCP server holds no database connection and no domain import. Provable by
  inspecting its dependency graph in a test.
- An agent authenticated as Technician can do exactly what a human Technician can
  do through REST, and nothing more.
- The OpenAPI document is generated from the implementation, not maintained
  beside it.

---

## 2. Functional Requirements

### 2.1 Service decomposition (FR-010)

**Description**: Eleven domain services — identity, registry, storage, workflow,
eln, search, audit, file, labkey-bridge, mcp-server, notify.

**Acceptance Criteria**: each service owns its tables; cross-service reads go
through the service, not the other service's tables. The MCP server is a client,
not a peer with database access.

### 2.2 Core REST endpoints (FR-043)

**Description**: The named endpoints of §10.

| Endpoint | Feature |
| --- | --- |
| `POST /samples` (intake) | FRD-001 |
| `POST /storage/moves` | FRD-003 |
| `POST /jobs` | FRD-004 |
| `POST /notebooks/{id}/sign` | FRD-005 |
| `GET /search` | FRD-006 |

**Acceptance Criteria**:
- Every write endpoint opens its transaction through the unit-of-work helper, so
  the audit event is unavoidable (FRD-007 §2.1).
- Every endpoint declares its required role; the declaration is the enforcement,
  not a comment.
- Errors follow the codes each feature's §6 specifies — 409 for conflicts, 404
  for cross-boundary invisibility (FRD-008 §6), 422 for validation.
- Idempotency: a retried `POST` with an idempotency key does not double-write
  (AGENTS.md §4).

**Edge Cases**: a client retrying after a timeout where the write actually
committed (the idempotency key returns the original result, not a duplicate).

### 2.3 MCP tool namespaces (FR-044)

**Description**: `osm.samples.*`, `osm.storage.*`, `osm.jobs.*`,
`osm.eln.append_ref` (**draft only**), `osm.audit.for_entity`,
`osm.labkey.publish_status`.

**Acceptance Criteria**:
- **Tools mirror REST semantics exactly** (FR-008). A tool is a translation of a
  REST call, including its error codes; it does not add behaviour, relax a check,
  or batch several writes into one opaque step.
- Each tool call carries the agent's identity to REST; the MCP server never holds
  a privileged credential of its own.
- The tool set exposed to a session is fixed at authentication time (CON-012,
  FRD-011).

**Deliberately absent tools** — discard, ship, lock, sign, permission change
(PRO-005, PRO-006, PRO-007). A capability that must never be reachable is better
absent than refused at call time (REQ-14). A test asserts the tool list does not
contain them.

### 2.4 LLMs act only through tools (FR-064)

**Description**: No domain action without a tool. No SQL, no shell, outside the
declared tools (PRO-009).

**Acceptance Criteria**: the MCP server exposes no generic query tool, no SQL
passthrough and no filesystem access. The natural-language finder returns a typed
filter structure that the ordinary parser validates (FRD-006 §2.5).

### 2.5 OpenAPI

**Acceptance Criteria**: the document is generated, covers every endpoint, and
is part of the I0 acceptance gate (CON-013). A route absent from the generated
document is a route that does not exist.

---

## 3. Data Requirements

This feature owns no domain tables. It owns the API contract, the idempotency key
store (key, request hash, response, expiry) and the MCP session binding (session,
identity, **frozen tool allowlist**, created_at).

---

## 4. User Interface Requirements

None of its own — but the constraint runs the other way: the UI (FR-048, eight
areas) is a client of this API and gets no privileged path (CON-005). Any UI
feature that cannot be expressed as an API call is a design error in the API, not
a case for a back door.

---

## 5. Performance Requirements

- **NFR-003**: API P95 under 200 ms. This is the budget every other feature
  spends; the API layer's own overhead must be a small fraction of it.
- **NFR-004**: 100 concurrent users.
- **NFR-005**: one million samples — pagination is mandatory on every collection
  endpoint; there is no unbounded list.
- The MCP adapter adds one HTTP hop; it must not add a second round trip per tool
  call by fetching context it was already given.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Validation failure | 422, naming the field |
| Conflict (occupancy, version, status) | 409, naming the rule |
| Cross-boundary invisibility | 404 (FRD-008 §6) |
| Wrong role | 403, naming the required role |
| Unauthenticated | 401 |
| Retried write with an idempotency key | the original result |
| Downstream service unavailable | 503 with a retry hint; never a silent partial write |

MCP tool errors carry the REST status and reason through unchanged. An agent that
receives "409 slot occupied" can reason about it; one that receives "tool failed"
cannot.

---

## 7. Security Requirements

**Who may write.** The API enforces the roles each feature's §7 declares; it adds
no authority of its own. The MCP server holds **no** credential of its own — it
passes the caller's.

**Audit events emitted**: every write through either path produces its feature's
event, with `actor_type` set to `human`, `service` or **`mcp`** (FR-046), so
agent-initiated writes are distinguishable in the trail.

**Injection surfaces.**
- *Every* input crosses this boundary, so this is where typed validation happens
  first. Filter expressions are parsed into a typed structure and never
  concatenated into SQL (FRD-006 §7).
- File uploads: declared content type validated rather than trusted, size and row
  count bounded (FRD-001 §2.3).
- Barcodes: bounded, character-validated, 404 on unknown (FRD-003 §7).
- *Prompt injection*: the tool allowlist is bound to the session at
  authentication time and never derived from document content (CON-012). The MCP
  session binding in §3 is where that freeze is stored.

**Structural boundary (ADR-0006)**: the MCP server must not import the domain
services or open a database connection. This is enforced by a dependency test,
because it is the property the whole "agent cannot exceed its role" argument
rests on.

**Credentials** come exclusively from the environment, are never command-line
arguments, and are never logged (ADR-0008, AGENTS.md §3).

---

## 8. Dependencies

### Depends On
- FRD-008 (authorisation and identity) — the roles this layer enforces.
- FRD-007 (audit) — the unit-of-work helper that makes writes auditable.
- ADR-0006 (MCP server as a thin adapter over REST), ADR-0002 (stack).

### Depended On By
- FRD-001 through FRD-006 are exposed through it; FRD-010 exposes
  `publish_status`; FRD-011 (assistant support) is built entirely on it.

---

## 9. Open Questions

1. **Idempotency key lifetime and scope** are unspecified. Per endpoint, per
   user, how long?
2. Is there a rate limit per API key, and what is it? Nothing specifies one, and
   an agent with a key is exactly the client that needs one.
3. FR-067's three assistant channels (UI chat, external key on `POST /mcp`, batch
   service account) imply three trust levels. Do they share one tool list, or
   does the batch channel get a smaller one? Specified in FRD-011; the API-side
   consequence is undecided.
4. Are the eleven services separate deployables or modules in one process? FR-010
   names them; the deployment topology is an ADR that has not been written.

---

## 10. Non-Functional Requirements

NFR-003, NFR-004, NFR-005. **CON-005** is the defining constraint: one
authorisation path, no privileged UI. **CON-013** puts OpenAPI in the I0 gate and
"MCP+LabKey bridge done **when the UI runs through the API**" at I6 — the UI
running through the API is the acceptance, which is how CON-005 is proved rather
than asserted.
