# Feature Requirement Document (FRD): Tamper-Evident Audit

**Feature ID**: FRD-007
**Feature Name**: Hash-chained audit of every write, inside the domain transaction
**Related PRD Requirements**: REQ-7
**Memory Requirements**: FR-002, FR-007, FR-011, FR-020, FR-040, FR-041, FR-042, FR-070, CON-006, CON-008
**Spec Sections**: §1, §2, §3, §9
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Every write is audited inside the same transaction that performs it, so no code
path can produce an unaudited change. Events are chained with SHA-256 and
anchored by a daily checkpoint. The trail is exportable. The auditor can read it
and nothing else.

### Value Proposition

An audit log written *after* the fact, on a best-effort basis, records what the
application remembered to tell it. One written in the same transaction records
what actually happened, because the alternative to recording it is the write not
happening. That is the difference between a log and evidence.

The chain adds the second property: an append-only table can still be edited by
anyone with database access. With `prev_hash` on every event, editing history
requires rewriting every subsequent hash, and the daily checkpoint means even
that is detectable.

### Success Criteria

- There is **no code path** that writes domain data without an audit event —
  enforced structurally by the unit-of-work helper, not by review.
- Altering or deleting any historical event makes verification fail and names the
  first broken link.
- Verifying a year of events does not require replaying a year: the daily
  checkpoint bounds the work.
- The auditor role can read the trail and demonstrably nothing else.

---

## 2. Functional Requirements

### 2.1 Audit inside the domain transaction (FR-011, FR-002)

**Description**: The audit write and the domain write share one database
transaction. This is ADR-0003 and it is the load-bearing decision of the whole
system.

**Acceptance Criteria**:
- Writes are opened only through the unit-of-work helper, which is the only
  sanctioned way to open a write (AGENTS.md §7). It emits the audit event as part
  of committing.
- **If a code path can write without auditing, that is a defect** — a test
  enumerates the domain services and asserts each write goes through the helper.
- A rolled-back domain write leaves no audit event; a committed one always has
  exactly one.
- Chain of custody: intake, move, ship and discard are each attributable to an
  actor (FR-002).

**Edge Cases**: a bulk operation writing 10,000 rows (one transaction, one event
per row or one batch event with the row set — decided in §9); a write performed
by a scheduled pipeline (actor is the service account, `actor_type` records it).

### 2.2 Event content (FR-020)

**Description**: An `AuditEvent` stores before state, after state and the
previous hash.

| Field | Notes |
| --- | --- |
| `event_id` | monotonic within a project |
| `occurred_at` | database time, not client time |
| `actor`, `actor_type` | `human`, `service`, or **`mcp`** (FR-046) |
| `entity_kind`, `entity_id` | what changed |
| `action` | `sample.registered`, `storage.moved`, … |
| `before`, `after` | the state either side of the change |
| `reason` | free text where the operation class requires it (FR-070) |
| `prev_hash`, `hash` | the chain |

**Acceptance Criteria**:
- `before`/`after` exclude any field marked PHI; PHI never enters the trail
  (PRO-001, PRO-003).
- `reason` is **configurably required per operation class** (FR-070) — discard
  and ship may require it while a field edit does not.
- Agent-initiated writes are distinguishable by `actor_type=mcp` (FR-046).

### 2.3 The hash chain (FR-040)

**Description**: Each event stores the hash of its predecessor; tampering breaks
the chain.

**Acceptance Criteria**:
- `hash = SHA-256(canonical(event) || prev_hash)`, canonicalisation pinned as in
  FRD-005 §2.3.
- The chain is per project, so one project's volume does not serialise another's
  writes — and the checkpoint covers each chain.
- Verification reports the **first** broken link, not merely "invalid".
- Insertion is append-only: the database role holds `INSERT`/`SELECT` and no
  `UPDATE`/`DELETE` (AGENTS.md §3).

**Edge Cases**: concurrent writes competing for the same `prev_hash` (serialised
per chain by the database, not by an application lock that a second process could
ignore); the first event of a chain (`prev_hash` is a declared genesis value).

### 2.4 Daily checkpoint (FR-041, P-AUDIT-CKPT)

**Description**: A daily checkpoint anchors the chain so verification does not
need a full replay.

**Acceptance Criteria**:
- The checkpoint records the chain head hash and the event count at a point in
  time, and is itself immutable.
- Verification from the most recent checkpoint forward is the normal path;
  full-replay verification remains available.
- The job is idempotent: running it twice for one day produces one checkpoint
  (AGENTS.md §4).

### 2.5 Export (FR-042)

**Description**: The trail is exportable for an entity or a time range.

**Acceptance Criteria**:
- The export includes the hashes, so a third party can verify it offline.
- An export is itself an audited read.
- Rows outside the caller's visibility are absent from the export, and their
  absence must not silently break the chain for the recipient — the export
  states its bounds and includes the checkpoint that anchors them.

### 2.6 Verification API

**Acceptance Criteria**: available on demand, not only as a background job; a
failure returns a truthful result plus an alert, not a 500 (see FRD-005 §6).

---

## 3. Data Requirements

`AuditEvent` as tabled in §2.2, plus `AuditCheckpoint` (project, taken_at, head
hash, event count). Both are append-only by database grant. Retention is a
project property (FRD-001 §3) consumed by P-RETENTION (FRD-012) — and retention
**must not delete events inside the chain**; expiry is handled by sealing and
archiving a chain segment with its checkpoint, never by deleting links.

**CON-008**: LabKey's server audit supplements the OSM trail but never replaces
it. The bridge must not lower LabKey's audit level and must not assume it can
(CON-017) — LabKey enabled detailed audit for samples and data classes
automatically in 25.11.

---

## 4. User Interface Requirements

Audit appears in two places: the **sample timeline** (FRD-001 §2.5), which is
assembled from this trail rather than from a parallel log, and an **Admin**
audit view with entity/time filters, export and a visible verification state.
An auditor's view offers no write control anywhere (CON-006).

---

## 5. Performance Requirements

- The audit write is on the critical path of **every** domain write, so it must
  fit inside the API P95 of 200 ms (NFR-003) at 100 concurrent users (NFR-004).
  Hashing is cheap; the risk is chain-head contention, which is why the chain is
  per project.
- Verification from the last checkpoint is O(events since checkpoint).
- A bulk write of 10,000 rows must not produce 10,000 round trips.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Audit insert fails | the **domain write fails with it** — same transaction |
| Chain verification mismatch | 200 with `valid: false`, first broken link named, plus an alert |
| Checkpoint job run twice for a day | second run is a no-op |
| Auditor attempts any write | 403 |
| Export requested beyond retention | 200 with the sealed archive reference |

There is no degraded mode in which writes proceed unaudited. If the audit cannot
be written, the change does not happen.

---

## 7. Security Requirements

**Who may write.** Nobody writes the trail directly. Events are produced only by
the unit-of-work helper as a side effect of a domain write. The checkpoint job
runs as a service account. **No role, including Project admin, can update or
delete an event** — the grant does not exist (AGENTS.md §3).

**Who may read.** Project admin and **Auditor**. The auditor role is read-only:
it can read the trail and nothing else (CON-006), and this is verified by a test
that asserts the denials, not merely that reading works (AGENTS.md §6.4).

**Audit events emitted by this feature itself**: `audit.exported`,
`audit.verified`, `audit.checkpointed`. The trail records reads of the trail.

**Injection surfaces**: `reason` and `before`/`after` payloads are stored as
structured data and rendered as text; never interpolated into SQL. An export
filename derived from an entity id is sanitised — an id is untrusted input even
when it came from OSM.

**PHI**: no patient-identifiable data enters the trail. Study identifiers appear
only as opaque tokens (PRO-001, PRO-002); PHI is stripped when a publish payload
is built so it never reaches the queue (PRO-003) — and equally never reaches
`before`/`after`.

**Assistant boundary**: `osm.audit.for_entity` is a read tool (FR-044). An
assistant can read the trail for an entity and can write nothing into it.

---

## 8. Dependencies

### Depends On
- FRD-008 (roles — the auditor role and the database grants).
- ADR-0003 (hash-chained audit in the domain transaction) — this document is its
  specification.
- ADR-0002 (PostgreSQL; transactional semantics are the mechanism).

### Depended On By
- **Every other FRD.** FRD-001 through FRD-006 and FRD-009 through FRD-012 all
  emit events here, and FRD-001's timeline reads from it.

---

## 9. Open Questions

1. **Bulk granularity**: one event per row, or one batch event carrying the row
   set? Per-row is more useful and 10,000× more expensive at import scale. This
   needs an ADR before the CSV import lands (FRD-001 §2.3).
2. **Retention versus immutability**: sealing and archiving a chain segment is
   proposed in §3 but not specified anywhere. How long is a sealed segment kept,
   and where?
3. Should the daily checkpoint be published somewhere external (a notary, a
   second system) so that a full-database compromise is still detectable?
   Currently the checkpoint lives in the same database it anchors.
4. Read auditing — see FRD-006 §9.1.

---

## 10. Non-Functional Requirements

NFR-003, NFR-004. **CON-013** sets the I0 gate as "Auth/Audit/OpenAPI done **when
the hash chain verifies**" — the chain verifying is the acceptance, and it is the
first gate in the project. NFR-006 (seven-day point-in-time recovery, FRD-012)
interacts with immutability: a restore must land on a chain that still verifies,
which is a property the restore drill has to prove rather than assume.
