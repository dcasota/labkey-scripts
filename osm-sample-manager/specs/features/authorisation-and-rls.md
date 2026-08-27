# Feature Requirement Document (FRD): Authorisation and Row-Level Security

**Feature ID**: FRD-008
**Feature Name**: Seven-role authorisation over data protected by row-level security
**Related PRD Requirements**: REQ-8, REQ-15
**Memory Requirements**: FR-012, FR-013, FR-047, FR-080, CON-006, CON-015, PRO-007
**Spec Sections**: §2, §11
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Seven roles — Reader, Technician, Scientist, Reviewer, Storage/Workflow admin,
Project admin, Auditor — over data protected by row-level security **in the
database**, so that a defect in application code cannot expose another project's
samples.

### Value Proposition

Application-level authorisation fails open under the two conditions that matter
most: a new endpoint whose author forgot the check, and a query written against
the database directly. RLS fails closed for both. It moves the boundary from
"every developer remembers" to "the database refuses", which is the only version
that survives a growing codebase.

### Success Criteria

- A policy gap is impossible to introduce silently: **every new domain table gets
  an RLS policy, and a table without one fails a schema test** (AGENTS.md §3).
- Every role test asserts the **denials**. A role test that only proves access
  works has tested nothing (AGENTS.md §6.4).
- Removing the application's authorisation layer entirely would still not expose
  another project's rows — provable by running the query as the application
  database role with a foreign project context.

---

## 2. Functional Requirements

### 2.1 The seven roles (FR-047)

| Role | May |
| --- | --- |
| **Reader** | read within the project |
| **Technician** | create samples, storage operations, complete own tasks |
| **Scientist** | the above, plus start jobs, draft ELN, upload assays |
| **Reviewer** | approve and **sign** notebooks, return for changes |
| **Storage/Workflow admin** | design storage layout and job templates; override reservations |
| **Project admin** | all of the above within the project, plus role assignment |
| **Auditor** | **read the audit trail and nothing else** (CON-006) |

**Acceptance Criteria**:
- Roles are assigned per project, not globally; a user may hold different roles
  in different projects.
- The Auditor role is not a superset of Reader — it reads the trail, not the
  domain data, and a test asserts that denial explicitly.
- Signing is Reviewer-only (FRD-005); discard/ship/lock follow FRD-002 §7.

**Edge Cases**: a user holding both Scientist and Reviewer on one project (the
self-approval setting of FRD-005 §2.1 decides whether they may review their own
work; default off); the last Project admin removing their own admin role
(refused — a project must retain one).

### 2.2 Design authority separate from edit authority (FR-080)

**Description**: The right to change a *definition* — sample type, source type,
storage layout, job template — is a distinct grant from the right to edit the
data it governs.

**Acceptance Criteria**: a Technician may register a thousand samples and change
no field definition; a designer grant may be held without data-edit rights. The
grant is checked at the definition endpoints in FRD-001 §2.1, FRD-003 §2.1 and
FRD-004 §2.1. *Priority: should, iteration I0.*

### 2.3 Row-level security (FR-012)

**Description**: PostgreSQL RLS policies keyed on project, applied to every
domain table.

**Acceptance Criteria**:
- Every domain table has a policy. A new table without one **fails a schema
  test** — the protection cannot be forgotten.
- The application connects as a role that is subject to RLS. It does not connect
  as an owner or a `BYPASSRLS` role.
- The project context is set per transaction from the authenticated identity,
  never from a request parameter the client controls.
- Audit tables grant `INSERT`/`SELECT` and no `UPDATE`/`DELETE`; the auditor role
  gets `SELECT` only (AGENTS.md §3).

**Edge Cases**: a background worker acting across projects (it sets the project
context per unit of work and is never given a blanket bypass); a migration
needing owner rights (run as a separate role, in a separate connection, never
the application's).

### 2.4 Identity, OIDC and API keys (FR-013)

**Description**: The identity service provides OIDC login, role assignment and
API keys for machine clients.

**Acceptance Criteria**:
- Credentials come exclusively from the environment (ADR-0008). There are no
  defaults; a missing variable aborts with a message naming it.
- A credential is **never** passed as a command-line argument — arguments are
  visible in the process table — and never logged at any level. Log the URL and
  the status code (AGENTS.md §3).
- An API key carries a role and a scope; it cannot exceed the role it
  authenticates as.
- Re-authentication for ELN signing (FRD-005 §2.3) is provided here, and its
  freshness is enforced server-side.

**Edge Cases**: an OIDC provider outage (OSM does not fall back to a local
password path that would weaken the boundary; it fails closed and says so); a
revoked API key used mid-session (the next request fails).

### 2.5 Least privilege for the LabKey bridge

**Description**: The bridge uses a LabKey API key restricted to
`EditorWithoutDelete` (AGENTS.md §3), and OSM pins the LabKey version it targets
(CON-018, FRD-010).

**Acceptance Criteria**: the bridge cannot delete in LabKey even if OSM is
compromised; the restriction is asserted by an integration test, not assumed.

### 2.6 No content-derived privilege (REQ-15)

**Description**: The assistant tool allowlist is bound to the session at
authentication time and is never derived from document content (CON-011,
CON-012). Specified in full in FRD-011; named here because it is an
authorisation property.

**Acceptance Criteria**: a hostile SOP PDF asking for a tool changes nothing,
because the allowlist was fixed before the document was read.

---

## 3. Data Requirements

| Entity | Key fields |
| --- | --- |
| `User` | `user_id`, subject (from OIDC), status |
| `RoleAssignment` | user, project, role |
| `ApiKey` | key id, hash, owner, role, scope, expires_at |

An API key is stored as a **hash**, never in a recoverable form. No secret,
credential, key or token enters the repository, ever (ADR-0008, AGENTS.md §3).

---

## 4. User Interface Requirements

The **Admin** area (FR-048): user list, role assignment per project, API key
issue and revoke (showing the key exactly once, at creation). Controls a user may
not use are not shown — but the server refuses regardless, and the refusal is the
authoritative one.

---

## 5. Performance Requirements

RLS is evaluated on every row of every query, so policies must be index-friendly:
the project key is indexed and the policy predicate is sargable. A policy that
forces a sequential scan would breach NFR-002 (finder P95 < 300 ms at 1e6
samples) — the finder is where a bad policy shows first.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Authenticated, wrong role | **403**, naming the required role |
| Not authenticated | 401 |
| Row outside the caller's projects | **404**, not 403 — existence is not disclosed (CON-015) |
| Missing credential in the environment | abort at startup, naming the variable |
| Last Project admin self-demotion | 409 |
| Expired or revoked API key | 401 |

The 403/404 distinction is deliberate: 403 says "this exists and you may not have
it", which is itself a disclosure across a project boundary. Within a project the
caller may already see the row exists, and 403 is correct.

---

## 7. Security Requirements

**Who may write.** Role assignment: Project admin only. API key issue: the owner
for their own keys, Project admin for service accounts. RLS policies: nobody at
runtime — they are migrations, reviewed as code.

**Audit events emitted**: `role.assigned`, `role.revoked`, `apikey.issued`,
`apikey.revoked`, `auth.reauthenticated`, `auth.failed` — in the same transaction
as the change (FR-011, ADR-0003).

**Prohibition — assistants may never change permissions** (PRO-007). Permission
change is **not exposed as an MCP tool at all** (REQ-14, FRD-011): absent, not
refused.

**Injection surfaces**: the project context is set from the verified identity,
never from client input — a request parameter that could set the RLS context
would defeat the entire mechanism. Role names are enums, not free text.

**Never log a credential**, at any level, including on failure paths where the
temptation is greatest (AGENTS.md §3).

---

## 8. Dependencies

### Depends On
- ADR-0002 (PostgreSQL — RLS is why), ADR-0008 (credentials exclusively from the
  environment).
- FRD-007 (audit) for the events and the auditor role's grants.

### Depended On By
- **Every other FRD.** Each one names the roles that may perform each write in
  its §7, and every domain table each one adds carries a policy from here.

---

## 9. Open Questions

1. **Is "Storage/Workflow admin" one role or two?** FR-047 writes it as one
   compound; REQ-8 lists it as one of seven. Two would be cleaner, and the count
   of seven is stated in both. Needs a decision before I0 role tests are written.
2. Is cross-project read ever legitimate — a shared reference sample type, for
   instance? Assumed no; if yes it needs an ADR, because it is the one thing RLS
   makes deliberately hard.
3. Access recertification (periodic review of who holds what) was flagged as
   questionable scope in the premium-feature harvest. In or out?
4. MFA: not specified anywhere, including for signatories (FRD-005 §9.3).

---

## 10. Non-Functional Requirements

NFR-002 (a bad policy breaks the finder budget), NFR-003, NFR-004. **CON-013**
puts authorisation in the I0 gate alongside audit and OpenAPI, and CON-013's I5
gate requires "Search done **with RLS**" — so this feature is proved twice, once
at the start and once under the finder's load.
