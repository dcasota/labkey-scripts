# Feature Requirement Document (FRD): Sample Lifecycle

**Feature ID**: FRD-002
**Feature Name**: Eight-status sample lifecycle, enforced server-side
**Related PRD Requirements**: REQ-2
**Memory Requirements**: FR-022, FR-012, FR-079
**Spec Sections**: §2, §3, §13
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Eight statuses — Registered, Available, Reserved, In Process, Consumed, Locked,
Discarded, Shipped — and a declared set of transitions between them. Every
mutation elsewhere in OSM asks this feature whether it is allowed.

The reason this is its own document rather than a paragraph in the registry is
the project's characteristic failure mode. LabKey *appears* to have sample
status: `isOperationPermitted()` exists, and it returns `true` unconditionally.
Nothing is enforced (AGENTS.md §2). OSM's status is only worth having if it
actually refuses.

### Value Proposition

A consumed tube cannot be aliquoted, a discarded one cannot be shipped, and a
locked one cannot be edited during an investigation. These are the rules a
laboratory already has informally; making them a server-side gate turns a
convention that people forget under pressure into one the system keeps.

### Success Criteria

- Every forbidden transition is refused **by the API**, with the refusal covered
  by a test that asserts the denial — not merely a test that the allowed path
  works (AGENTS.md §6.4).
- No code path can change a status without emitting the transition audit event.
- The permitted transition set is data, inspectable, not scattered `if`
  statements.

---

## 2. Functional Requirements

### 2.1 The status model (FR-022)

**Description**: The lifecycle is a directed graph over eight statuses.

```
Registered ──> Available ──> Reserved ──> In Process ──┬─> Consumed
                   ^              │            │        ├─> Discarded
                   └──────────────┴────────────┘        └─> Shipped
     (any active status) ──> Locked ──> (previous status, admin only)
```

**Acceptance Criteria**:
- Transitions not in the declared set are refused with 409.
- `Consumed`, `Discarded` and `Shipped` are terminal: no transition leaves them.
- `Locked` is reversible, by Project admin only, and returns the sample to the
  status it held before locking.
- A sample type may permit a **subset** of the eight (FR-023, FRD-001); a
  transition to a status the type does not permit is refused even if the global
  graph allows it.

**Edge Cases**: locking a sample that is mid-transition; a type edited to remove
a status that existing samples currently hold (existing rows keep it and are
reported; they are not silently rewritten).

### 2.2 Enforcement points

**Description**: The gate is consulted by every operation that touches a sample.

| Operation | Refused when the sample is |
| --- | --- |
| Aliquot / derive (FRD-001) | Consumed, Discarded, Shipped, Locked |
| Check-in / check-out / move (FRD-003) | Discarded, Shipped, Locked |
| Assign to a job task (FRD-004) | Consumed, Discarded, Shipped, Locked |
| Any field edit | Locked |
| Picklist membership | *never refused* — the one mutation Locked permits |
| Publish to LabKey (FRD-010) | never refused; status travels with the payload |

**Acceptance Criteria**:
- Enforcement lives in the domain service, reached through the unit-of-work
  helper, so the REST API, the MCP server and a batch worker all hit the same
  check (CON-005).
- The check is not duplicated in the UI as the only barrier. Client-side
  validation is a convenience; the boundary is the only place that counts
  (AGENTS.md §3).

### 2.3 Reserved and its time limit

**Description**: `Reserved` corresponds to a slot reservation with a TTL
(FR-031, FRD-003). When the reservation expires the sample returns to
`Available`.

**Acceptance Criteria**: expiry is driven by a scheduled sweep that is idempotent
(AGENTS.md §4) and emits an audit event per sample it releases; a sample that
moved on by itself is left alone.

### 2.4 Status as a lineage filter (FR-079)

**Description**: The lineage graph can be filtered by status, hiding matching
nodes while preserving the connectivity of the paths that remain.

**Acceptance Criteria**: hiding a node must not silently break an ancestry path —
the edge is drawn through the hidden node, or the node is shown as an
unidentified ellipsis, never omitted in a way that implies a direct
parent-child link that does not exist. *Priority: could, iteration I5.*

---

## 3. Data Requirements

`Sample.status` is a constrained enum column, not free text. Permitted
transitions live in a `status_transition` table (from, to, roles_permitted) so
the rule set is queryable and diffable, not compiled in. `Sample.locked_from`
holds the status to restore when a lock is lifted.

Row-level security applies to the transition table as it does to every domain
table (AGENTS.md §3).

---

## 4. User Interface Requirements

Status is shown wherever a sample is referenced, as one of the identifying
fields (FR-071). Transitions the current user may not perform are not offered.
The UI must not present a control that the server will refuse — but the server
refuses regardless.

---

## 5. Performance Requirements

The gate is on the write path of every sample operation, so it must not cost a
round trip: the transition set is cached in process and invalidated on change.
Bulk operations evaluate the gate per sample but in one transaction — a 10,000
row bulk status change is one transaction, not 10,000.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Transition not in the declared set | 409, naming current and requested status |
| Status not permitted by the sample type | 409, naming the type |
| Mutation of a Locked sample | 409, naming the lock and who set it |
| Unlock by a non-admin | 403 |
| Concurrent transition of the same sample | 409 (optimistic version check) |

A refusal names the rule that refused. "Operation not permitted" without a reason
is a defect: the technician needs to know which status is blocking them.

---

## 7. Security Requirements

**Who may write.** Registered → Available, Available → Reserved → In Process:
Technician, Scientist, Project admin. Consumed: Technician, Scientist. Discarded
and Shipped: Technician with the storage grant, or Project admin. Locked and
unlock: Project admin only. Reader and Auditor never transition anything
(CON-006).

**Audit event emitted**: `sample.status_changed`, carrying before and after
status, the actor, and the reason for change where the operation class requires
one (FR-070). Written in the same transaction as the status update (FR-011,
ADR-0003) — a status change that is not audited is a defect, not a degraded mode.

**Prohibition.** An assistant may never discard, ship or lock a sample without a
human (PRO-005). This is enforced by **not exposing those transitions as MCP
tools at all** (FRD-011) — absent, not refused at call time.

**Injection surfaces**: none directly; this feature accepts an enum and a free
text reason. The reason is stored and rendered as text, never interpolated into
SQL or shell.

---

## 8. Dependencies

### Depends On
- FRD-001 (registry) — the samples whose status this governs.
- FRD-007 (audit), FRD-008 (roles and RLS).
- ADR-0003 (audit inside the domain transaction).

### Depended On By
- FRD-001, FRD-003, FRD-004, FRD-005, FRD-006, FRD-010 — every one of them
  consults the gate.

---

## 9. Open Questions

1. May a `Shipped` sample be received back? The specification lists Shipped as
   terminal, but real laboratories do get returns. If OSM should support it, the
   answer is a new sample with a lineage link to the shipped one — **needs an
   ADR** rather than an implementation decision.
2. Does `Reserved` expiry notify the reserver? Assumed yes, through FRD-004's
   notification path; not stated in the specification.

---

## 10. Non-Functional Requirements

CON-013 makes the lifecycle part of the I1 acceptance gate ("Registry done at
aliquot") — aliquoting cannot be accepted until the gate refuses aliquoting of a
consumed sample. NFR-003 (API P95 < 200 ms) applies: the gate must not be the
reason a write misses it.
