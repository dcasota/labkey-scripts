# ADR-0004: Slot Occupancy Enforced By A Database Constraint

**Date**: 2026-08-26
**Status**: Accepted

## Context

§5 requires a five-level storage hierarchy where a slot holds exactly one
sample, check-in/check-out/move are atomic, a box move is an atomic batch, slots
can be reserved with a TTL, and a conflict returns HTTP 409. §3 gives
`StorageNode/Slot` the field `occupied_by`.

The freezer map has its own acceptance gate (§19), and NFR-001 requires 1000
boxes of 81 slots — roughly 81 000 slots — to render without stutter.

The naive implementation reads a slot, sees it free, and writes. Between the
read and the write another transaction can do the same. Two samples then occupy
one slot, which is a physical-world integrity failure: the freezer map stops
being 1:1 with reality, which is the single thing §5 exists to guarantee.

## Decision Drivers

- §5's "one sample per slot" is a physical invariant; it must not be violated
  even briefly, and must not depend on application-level checking.
- Reservations (TTL) and occupancy compete for the same slot, so both must be
  covered by one rule.
- The 409 in §5 must be a real conflict signal, not a best-effort race loser.
- Box moves must be all-or-nothing across up to 81 slots.

## Considered Options

### Option 1: Application-level check-then-write

**Description**: The storage service reads the slot, verifies it is free, then
writes the occupancy.

**Pros**:
- Simplest to write and to read.
- Error messages are easy to make friendly.

**Cons**:
- Races under concurrency, which is disqualifying for a physical invariant.
- Would need `SERIALIZABLE` isolation to be correct, costing far more than the
  alternatives.

### Option 2: Unique constraint on the occupancy column

**Description**: `UNIQUE (slot_id) WHERE occupied_by IS NOT NULL`, a partial
unique index on the slot occupancy table.

**Pros**:
- The database rejects a double-occupancy outright; the race is eliminated
  rather than narrowed.
- Cheap: a single index, no extension required.
- A constraint violation maps cleanly onto the 409 §5 requires.

**Cons**:
- Expresses occupancy only. A TTL reservation held on a free slot is a
  different state and needs a second rule, so the invariant lives in two places.

### Option 3: Exclusion constraint over slot and validity period

**Description**: Model both occupancy and reservation as a single
`slot_assignment` row carrying a `tstzrange` of validity, and enforce
`EXCLUDE USING gist (slot_id WITH =, valid_during WITH &&)` via `btree_gist`.

**Pros**:
- One rule covers occupancy and reservation: a slot cannot have two overlapping
  assignments of any kind.
- TTL expiry becomes a property of the data (`valid_during` upper bound) rather
  than a sweeper job that might not run — an expired reservation stops
  conflicting automatically at the instant it expires.
- Gives a truthful history of what occupied a slot when, which §1's chain of
  custody wants anyway.

**Cons**:
- Requires the `btree_gist` extension.
- GiST exclusion is more expensive to maintain than a btree unique index.
- Range semantics are less obvious to a reader than a boolean occupancy flag.

## Decision Outcome

**Chosen Option**: Option 3 — exclusion constraint over slot and validity range.

**Rationale**:

- It is the only option where the TTL reservation in §5 and the occupancy in §5
  are the same invariant rather than two rules that can drift apart.
- Automatic expiry matters operationally: with Option 2 a crashed sweeper leaves
  slots permanently blocked, and the failure is silent. With Option 3 there is
  no sweeper to crash.
- The historical record it produces is the chain of custody §1 requires, so the
  cost is shared across two requirements rather than charged to one.
- `btree_gist` is a standard contrib extension, present in PostgreSQL 18.

Option 2 remains an acceptable fallback if the exclusion constraint proves too
costly under load; the migration between them is mechanical. That judgement must
come from the NFR-001 benchmark, not from taste.

## Consequences

### Positive

- Double occupancy is impossible, not merely unlikely.
- A conflict surfaces as a specific PostgreSQL error code that maps
  deterministically to HTTP 409.
- Reservation expiry needs no background job.
- Slot history is a byproduct, feeding both the sample timeline (§4) and the
  audit export (§9).

### Negative

- `btree_gist` must be installed by migration, which the deployment must not
  silently skip. The migration fails loudly if the extension cannot be created.
- GiST index maintenance cost must be measured against NFR-001's 81 000 slots
  before the freezer-map acceptance gate is claimed.

### Neutral

- Box moves are ordinary multi-row transactions; atomicity comes from the
  transaction, and the constraint makes partial success impossible to observe.
- The rendering target in NFR-001 is a frontend concern and is unaffected by
  this choice; the API only needs to return a box's 81 slots efficiently.

## Implementation Notes

- Slot geometry uses `(row, col)` with an A1 origin per §5, stored as integers
  and rendered as a label, so a 9x9 box is `A1`..`I9`.
- The 409 response body names the conflicting slot and the occupying sample so
  the caller can act, without leaking data the caller may not read — the
  occupying sample id is included only when the caller can read that sample.

## References

- `specs/source/spezifikation-extract.md` §1, §3, §4, §5, §9, §19
- Memory: `FR-003`, `FR-016`, `FR-028`, `FR-029`, `FR-030`, `FR-031`,
  `FR-032`, `NFR-001`
