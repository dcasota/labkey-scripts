# Feature Requirement Document (FRD): Freezer Map

**Feature ID**: FRD-003
**Feature Name**: Five-level storage hierarchy with one-to-one physical correspondence
**Related PRD Requirements**: REQ-3
**Memory Requirements**: FR-003, FR-016, FR-028, FR-029, FR-030, FR-031, FR-032, FR-058, FR-073, FR-074, FR-050, NFR-001, NFR-008
**Spec Sections**: §1, §3, §5, §15, §17.1
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

A model of the physical storage that corresponds to it one-to-one: five levels
from site down to slot, where a slot holds at most one sample. Check-in,
check-out and move are atomic, a box move relocates its contents in one
transaction, slots can be reserved with a time limit, and a conflict returns a
conflict rather than silently overwriting.

This is the capability LabKey CE conclusively does not have. `InventoryService.
get()` returns `null` and the storage columns are silently absent (AGENTS.md §2);
the freezer lives in the paid tiers, and the two third-party bridges that once
substituted for it — FreezerPro and SampleMinded — were removed in LabKey 25.3.
Since March 2025 there is no freezer capability in CE from any direction.

### Value Proposition

The question "where is this tube, physically, right now" has to be answerable
without opening the freezer. And the inverse: "what is in this box" must match
what a person finds when they pull it out. A map that drifts from the shelf is
worse than no map, because people stop checking it.

### Success Criteria

- Two people cannot put two samples in one slot. Not "should not" — cannot, by a
  database constraint (ADR-0004).
- A box move of 81 samples either moves all 81 or none.
- The map renders 1000 boxes of 81 slots — about 81,000 slots — without stutter
  (NFR-001).
- A reservation that is never used disappears by itself.

---

## 2. Functional Requirements

### 2.1 Five-level hierarchy (FR-028, FR-016)

**Description**: site/building/room (a list) → device (status, zone) →
rack/drawer (grid, capacity) → box/plate (rows × columns, A1 origin) → slot
(cell).

**Inputs**: level type, parent node, geometry (rows, columns, labelling scheme),
capacity, optional barcode.

**Outputs**: `StorageNode` rows forming a tree, and `Slot` rows for a box's
geometry generated at creation.

**Acceptance Criteria**:
- Box geometry is supported to at least 50 rows by 50 columns for labelling,
  rendering and slot addressing (NFR-008).
- A1 is the origin; row and column labelling schemes (alpha-numeric, numeric)
  are per box.
- A node cannot be its own ancestor; the tree is a tree.
- A node with occupied descendants cannot be deleted — it can be archived.

**Edge Cases**: a box redefined to a smaller geometry while slots are occupied
(refused, naming the occupied slots outside the new bounds); a device marked out
of service while holding samples (permitted, flagged, and blocked for new
check-ins).

### 2.2 Slot occupancy (FR-032)

**Description**: A slot holds at most one sample, enforced by the database.

**Acceptance Criteria**:
- Occupancy is enforced by a database constraint, **not by application checks
  alone** (ADR-0004). The test that matters is two concurrent check-ins to the
  same slot: exactly one succeeds, the other receives 409.
- The constraint holds under concurrency without a table lock — a partial unique
  index or exclusion constraint, so throughput does not collapse.

**Edge Cases**: a slot freed and re-occupied inside one transaction (permitted);
a sample recorded in two slots by a bad migration (the constraint makes it
impossible to write, and a schema test proves the constraint exists).

### 2.3 Check-in, check-out and move (FR-029, FR-058)

**Description**: P-CHECKIN occupies a slot; P-CHECKOUT frees it and sets the
sample to `Reserved`; a move is a check-out and check-in evaluated as one
operation.

**Acceptance Criteria**:
- A move either fully succeeds or leaves **both** slots unchanged. There is no
  intermediate state in which the sample is in neither.
- The lifecycle gate (FRD-002) is consulted first: a Discarded, Shipped or
  Locked sample is not moved.
- Check-out is recorded both as an event and as a queryable timestamped
  attribute of the sample — a `CheckedOut` column — so "what is currently out"
  is a filter rather than an audit replay (FR-073).

**Edge Cases**: moving a sample to the slot it already occupies (no-op success,
idempotent per AGENTS.md §4); moving into a box in an out-of-service device
(refused).

### 2.4 Box move as an atomic batch (FR-030)

**Description**: Relocating a box moves every sample it contains in one
transaction.

**Acceptance Criteria**:
- All contained samples move, or none do.
- The destination's free capacity is checked before any row is written.
- One audit event per sample plus one for the box move, all in the same
  transaction (FR-011).

**Edge Cases**: destination partially occupied (refused before writing, naming
the conflicting slots); a box containing a Locked sample (refused — the lock
blocks the move; the alternative would let a lock be circumvented by moving its
container).

### 2.5 TTL slot reservation (FR-031)

**Description**: A slot can be reserved for a bounded time and is released
automatically on expiry.

**Acceptance Criteria**:
- A reserved slot rejects check-in by anyone except the reserver.
- Expiry is swept idempotently and audited.
- Reserving an occupied slot is refused with 409.

**Edge Cases**: the reserver checks in one second after expiry and someone else
has taken the slot (409, and the message says the reservation expired rather
than implying a bug).

### 2.6 Storage unit barcodes (FR-074)

**Description**: A terminal storage unit — box, plate, rack position — carries
its own barcode, unique across the deployment, so scanning a container is as
direct as scanning a sample.

**Acceptance Criteria**: uniqueness is deployment-wide, not per project; a
barcode that does not resolve returns **404**, never an error that reveals
whether the id exists in another project (AGENTS.md §3). *Priority: should,
iteration I2.*

### 2.7 Label printing (FR-050)

**Description**: ZPL label printer support, unresolved in the specification.

**Acceptance Criteria**: deferred. When implemented, a printer failure must never
fail the storage operation — the print is queued. *Priority: could.*

---

## 3. Data Requirements

| Entity | Key fields |
| --- | --- |
| `StorageNode` | `node_id`, parent, level, name, geometry, capacity, status, barcode |
| `Slot` | `slot_id`, node, row, column, label, `occupied_by`, reserved_by, reserved_until |

`Slot.occupied_by` carries the constraint that enforces §2.2. `Sample` gains
`checked_out_at` and `checked_out_by` (FR-073). Every table carries an RLS policy
keyed on project (AGENTS.md §3).

The migration that creates the exclusion constraint requires `btree_gist`; if the
extension cannot be created the migration **aborts** rather than continuing with
an application-level check (AGENTS.md §4).

---

## 4. User Interface Requirements

The **Map** area (FR-048). A drill-down from site to slot; a box view drawn as a
grid with A1 at top left; occupied, reserved, free and out-of-service
distinguished without relying on colour alone (NFR-007, WCAG 2.2 AA). Drag to
move, with the same server-side checks — the drag is a convenience, the refusal
is authoritative.

---

## 5. Performance Requirements

- **NFR-001**: 1000 boxes × 81 slots ≈ 81,000 slots render smoothly. The box grid
  is virtualised; the map does not fetch every slot of every box to draw a
  device.
- **NFR-008**: geometry to 50 × 50 must hold for labelling, rendering and slot
  addressing.
- A box move of 81 samples completes inside the API P95 budget (NFR-003) or is
  explicitly an asynchronous job with a progress record — not a request that
  silently takes ten seconds.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Slot occupied | **409**, naming the occupying sample if the caller may read it |
| Slot occupied by an unreadable sample | 409, without naming it (CON-015) |
| Reserved by another user | 409, naming the expiry time |
| Destination capacity insufficient | 409, before any write |
| Sample status forbids the move | 409, naming the status |
| Unknown barcode | **404** — never "exists in another project" |
| `btree_gist` unavailable | migration aborts loudly |

---

## 7. Security Requirements

**Who may write.** Check-in, check-out, move: Technician, Scientist, Project
admin. Box move and reservation override: Storage admin, Project admin. Creating
or editing the hierarchy: Storage admin with the design grant (FR-080). Reader
reads; Auditor reads the trail only (CON-006).

**Audit events emitted**: `storage.checked_in`, `storage.checked_out`,
`storage.moved`, `storage.box_moved`, `storage.reserved`, `storage.released`,
`storage.node_created`, `storage.node_archived` — each in the same transaction as
the change (FR-011, ADR-0003), each recording the source and destination slot.

**Injection surface — barcode input.** Scanned input is untrusted: bound its
length, validate its characters, never interpolate it into a query. An
unresolved barcode returns 404 rather than an error that discloses whether the id
exists elsewhere (AGENTS.md §3).

**Cross-boundary disclosure.** A slot occupied by a sample in a project the
caller cannot read reports *occupied* without identifying the occupant
(CON-015). The map must not become a directory of other projects' samples.

**Row-level security** on `StorageNode` and `Slot` keyed on project; a device
shared between projects is modelled by project-scoped child nodes, not by
relaxing the policy.

---

## 8. Dependencies

### Depends On
- FRD-001 (registry) and FRD-002 (lifecycle gate).
- FRD-007 (audit), FRD-008 (roles, RLS).
- ADR-0004 (slot occupancy enforced by a database constraint) — the decision this
  feature exists to honour.

### Depended On By
- FRD-004 (jobs) — storage operations are available as job tasks (FR-075).
- FRD-006 (finder) — storage location is a facet.
- FRD-010 (publishing) — `storage_path` is published as a plain string; the map
  itself does not travel to LabKey (FR-053).

---

## 9. Open Questions

1. Should a reservation be transferable between users, or only cancelled and
   re-made? Assumed the latter.
2. FR-050 (ZPL) is unresolved in the specification; the protocol, printer
   discovery and label template format are all undecided.
3. Does a rack/drawer need slot-level addressing of its own, or is it purely a
   container for boxes? Assumed a container, per §5's geometry only at box level.

---

## 10. Non-Functional Requirements

NFR-001 and NFR-008 above. CON-014 gives the freezer map an **independent
acceptance**, and CON-013 sets the I2 gate as "Freezer map done per §5" —
so §5's five levels, atomicity and 409 behaviour are the acceptance, not a
subset. Idempotency: re-running a check-in for a sample already in that slot
succeeds (AGENTS.md §4).
