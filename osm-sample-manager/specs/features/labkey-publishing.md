# Feature Requirement Document (FRD): LabKey Publishing

**Feature ID**: FRD-010
**Feature Name**: Transactional outbox publishing to LabKey Community Edition
**Related PRD Requirements**: REQ-10, REQ-13, REQ-16
**Memory Requirements**: FR-009, FR-021, FR-051, FR-052, FR-053, FR-054, FR-055, FR-061, CON-003, CON-009, CON-016, CON-017, CON-018, PRO-003, PRO-004
**Spec Sections**: §1, §3, §16, §16.1, §16.2, §17.3
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

A transactional outbox delivers committed samples, uploaded assays and signed
notebooks into LabKey CE. Publishing is idempotent, survives LabKey being
unavailable, and reports failures with the response body rather than discarding
them.

### Value Proposition

LabKey is where the institution's other data already lives, and where
collaborators expect to find results. But **OSM is the system of record and
LabKey is strictly downstream** (CON-003, ADR-0001). If a change makes OSM
depend on LabKey being available, it is wrong. The outbox is what buys both: the
domain write commits regardless, and delivery catches up.

### Success Criteria

- LabKey being down for a day costs nothing but latency; no OSM write fails and
  no publish is lost.
- Publishing the same object twice produces one row in LabKey, not two
  (FR-054).
- A failure is stored **with the response body** and is diagnosable without
  re-running it.
- A LabKey version change fails the integration suite until the claims are
  re-verified (CON-018).

---

## 2. Functional Requirements

### 2.1 The transactional outbox (FR-021, ADR-0005)

**Description**: `PublishOutbox(outbox_id, target, state)` is written **in the
same transaction** as the domain change that triggers it. A worker drains it.

**Acceptance Criteria**:
- The outbox row and the domain write share one transaction, so a committed
  sample always has its publish intent and an aborted one never does.
- The worker is at-least-once; idempotency (§2.4) makes that safe.
- States are explicit: `pending`, `in_flight`, `done`, `failed`. A `failed` row
  retains the LabKey response body (FR-055).
- Retries use bounded backoff and stop at a declared limit, after which the row
  stays `failed` and is surfaced — **not silently dropped** (AGENTS.md §4).

**Edge Cases**: a worker crashing mid-flight (the row returns to `pending` after
a visibility timeout, and idempotency absorbs the repeat); LabKey returning 200
with an error body (treated as a failure — the body is parsed, not assumed).

### 2.2 Outbox triggers (FR-055)

**Description**: The worker consumes three events: `sample.committed`,
`assay.uploaded`, `notebook.signed`.

**Acceptance Criteria**: each maps to a pipeline in §2.5; an event with no
mapping is a defect, not a no-op.

### 2.3 Object mapping (FR-052)

| OSM | LabKey |
| --- | --- |
| Sample, Aliquot, Lineage | `experiment` Sample Types |
| Source | Data Classes |
| AssayRun | assay |
| Catalogues | list |
| File pointers | WebDAV |

**Acceptance Criteria**: the map is data, not scattered conditionals, so a new
object type is a table entry plus a test.

### 2.4 Mapping rules and idempotency (FR-053, FR-054)

**Description**: Project → LabKey project/subfolder; `human_id` unique plus an
AutoIncrement key; lineage as lookups; **`storage_path` as a plain string** —
the map itself does not travel, because LabKey CE has no freezer to receive it
(FRD-003 §1). `osm_id` is carried into LabKey so re-publishing does not
duplicate.

**Acceptance Criteria**:
- Re-publishing the same object **must not duplicate rows** (FR-054). The
  integration test publishes twice and asserts one row.
- `osm_id` is present on every published row and is the merge key.
- Lineage lookups resolve to already-published parents; a child whose parent is
  not yet published waits rather than publishing a dangling reference.

**Edge Cases**: an object edited in OSM after publishing (a second publish
updates in place by `osm_id`); a LabKey row edited by hand (OSM overwrites on the
next publish — OSM is the system of record).

### 2.5 Publish pipelines (FR-061)

`P-LK-SAMPLE`, `P-LK-ASSAY`, `P-LK-LIST`, `P-LK-STUDY`, all driven by the
outbox.

**Acceptance Criteria**:
- **P-LK-STUDY requires Subject and Timepoint, otherwise reject** (CON-009). A
  study publish missing either is rejected at validation, not attempted.
- Each pipeline follows trigger → validation → action → audit → publish
  (FR-056).

### 2.6 LabKey API conventions (FR-051)

**Description**: CSRF, `createContainer`, Domain, `query-import`, `wiki-save`,
WebDAV — reusing the established script conventions.

**Acceptance Criteria** (these are verified facts, not assumptions — AGENTS.md
§7):
- Bootstrap the session via `login-whoAmI.api`; do **not** follow redirects; do
  **not** use `curl -f`, because 4xx bodies are needed.
- The import action is **`query-import.api`**, not `query-importData.api`.
- **`experiment-saveMaterials.api` does not exist.**
- TLS verification is skipped **only** for loopback (ADR-0008).
- The API key is restricted to `EditorWithoutDelete` (FRD-008 §2.5).

### 2.7 Container targeting (CON-016)

**Description**: Each import is issued **against the container that is to receive
the rows**.

**Acceptance Criteria**: the worker must not rely on importing into one container
from another — LabKey removed cross-folder import. A publish that would need it
fails validation with an explanation rather than at the HTTP layer.

### 2.8 Portals as folder archives (PRO-004, FR-009)

**Description**: **Do not use `addWebPart`.** Portals are delivered as
`folder.xml` zip archives.

**Acceptance Criteria**: a test asserts `addWebPart` appears nowhere in the
bridge. This is a prohibition verified by absence (REQ-16).

### 2.9 Version pinning (CON-018)

**Description**: The bridge records the LabKey version it was verified against;
a version change fails the integration suite until the claims are re-verified.

**Acceptance Criteria**: in eighteen months LabKey moved workflow tables out of
`sampleManagement` into a new schema — the pin exists because that happens.

---

## 3. Data Requirements

`PublishOutbox` (outbox_id, trigger event, entity kind/id, target container,
state, attempts, last_response_body, last_attempt_at, `osm_id`). Retained after
`done` for a bounded window so that "was this published, and when" is answerable.
RLS keyed on project like every other table.

---

## 4. User Interface Requirements

Within **Admin**: an outbox view showing pending, in-flight and failed rows with
their response bodies, and a manual retry. A failed publish must be visible to an
operator without reading logs. `osm.labkey.publish_status` exposes the same
read to an assistant (FR-044).

---

## 5. Performance Requirements

Publishing is asynchronous by construction, so it does not consume the API P95
budget (NFR-003). The worker must keep up with sustained registration — a bulk
import of 10,000 samples produces 10,000 outbox rows that drain without
starving interactive work, batched where `query-import.api` allows.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| LabKey unavailable | row stays `pending`, backoff, **no OSM write fails** |
| LabKey 4xx | `failed` with the **response body** retained (FR-055) |
| LabKey 200 with an error body | `failed` — the body is parsed, not assumed |
| Study publish missing Subject/Timepoint | rejected at validation (CON-009) |
| Parent not yet published | deferred, not dangling |
| Retry limit reached | stays `failed` and is surfaced; never dropped |
| LabKey version differs from the pin | integration suite fails (CON-018) |

`|| true` is acceptable only where the outcome is then explicitly checked
(AGENTS.md §4). A discarded publish failure is a defect.

---

## 7. Security Requirements

**Who may write.** Nobody publishes by hand in the normal path — the outbox is
written by the domain transaction. Manual retry: Project admin. Bridge
configuration: Project admin. Reader and Auditor never publish (CON-006).

**Audit events emitted**: `publish.queued`, `publish.succeeded`,
`publish.failed`, `publish.retried` — the queue row is written in the domain
transaction (FR-011, ADR-0003), and delivery outcomes are audited as they occur.

**PHI is stripped when the payload is built** (PRO-003), so it never reaches the
queue — not stripped at send time, when a queued payload would already contain
it. Study identifiers travel only as opaque tokens (PRO-001, PRO-002).

**Least privilege**: the LabKey API key is restricted to `EditorWithoutDelete`,
so a compromised bridge cannot delete in LabKey (AGENTS.md §3). Credentials come
from the environment only, are never command-line arguments, and are never
logged — log the URL and the status code (ADR-0008).

**Audit level (CON-017)**: the bridge must not pass an audit-suppressing
parameter and must not depend on suppression working. LabKey enabled detailed
audit for Samples, Sources, Data Classes and Assay Data automatically in 25.11.
**CON-008**: LabKey's server audit supplements the OSM trail; it never replaces
it.

**Injection surfaces**: values published into LabKey pass through `query-import`
as data, never as LabKey SQL. LabKey SQL supports `USERID()`, `||`, `COALESCE`,
joins and subqueries — a hostile field value must never reach a query text
(AGENTS.md §3). WebDAV paths derived from sample ids are sanitised.

**Boundary**: the bridge is the **only** sanctioned way this project touches the
running LabKey deployment (AGENTS.md §5), and it must never make OSM depend on
LabKey being available (CON-003, ADR-0001).

---

## 8. Dependencies

### Depends On
- FRD-001 (samples), FRD-005 (signed notebooks), FRD-004 (assay uploads),
  FRD-007 (audit), FRD-008 (the restricted API key).
- ADR-0005 (transactional outbox), ADR-0001 (OSM is the system of record),
  ADR-0008 (credentials from the environment).
- `docs/labkey-ce-ground-truth.md` and `docs/labkey-release-notes-survey.md` —
  the verified behaviour this bridge is built against.

### Depended On By
- Nothing in OSM. That is the point: publishing is a leaf, and its failure is
  contained.

---

## 9. Open Questions

1. **Which LabKey version is the pin?** CON-018 requires one; the value is not
   recorded anywhere yet. It must be set before the I6 integration suite.
2. Does a `sample.updated` event republish, or only `sample.committed`? FR-055
   names three triggers and update is not among them, yet §2.4's edge case
   assumes republishing.
3. Cross-folder moves of audited objects were flagged as questionable scope in
   the premium harvest — does OSM need to model them at all?
4. How long are `done` outbox rows retained (§3 says "a bounded window")?

---

## 10. Non-Functional Requirements

Idempotency is the defining non-functional property here and it is stated three
times (FR-054, ADR-0005, AGENTS.md §4): every script and installer is safe to
re-run, and creating something that exists is success, not an error. **CON-013**
sets the I6 gate as "MCP+LabKey bridge done when the UI runs through the API".
NFR-006 (seven-day PITR) covers the outbox: a restore must not resurrect a
publish that already happened, which idempotency guarantees.
