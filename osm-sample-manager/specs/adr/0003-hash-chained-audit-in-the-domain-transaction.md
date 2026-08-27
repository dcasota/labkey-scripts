# ADR-0003: Tamper-Evident Audit Written Inside The Domain Transaction

**Date**: 2026-08-26
**Status**: Accepted

## Context

§2 states *"Jede Schreiboperation auditiert in derselben Transaktion"* and §9
requires an append-only trail with a SHA-256 chain, a daily checkpoint and an
export. §3 gives `AuditEvent` the fields `before`, `after`, `prev_hash`. §11
makes `Auditor` a read-only role. §16.1 says the LabKey server audit is a
supplement that must not replace the OSM trail.

This is the requirement that ADR-0001 turned on, so the mechanism has to be
right. Two distinct properties are being asked for: **completeness** (no domain
write escapes auditing) and **tamper evidence** (a modified or deleted event is
detectable).

A hash chain gives tamper evidence only if the chain is actually sequential.
Under concurrent writers, naively reading "the last hash" and inserting races:
two transactions can read the same `prev_hash` and produce a fork that looks
valid in isolation.

## Decision Drivers

- Completeness must not depend on developers remembering to call an audit
  function.
- The chain must be linear under §14's 100 concurrent users.
- Verification must not require replaying the entire history (§9's checkpoint).
- The auditor must be able to read the trail and nothing else (§11).
- An LLM-initiated write must be distinguishable from a human one (§10,
  `actor_type=mcp`).

## Considered Options

### Option 1: Application-level audit helper called by each service

**Description**: Each domain service calls `audit.record(...)` inside its own
transaction. The helper computes the hash from the previous row.

**Pros**:
- Simple, portable, easy to test.
- Full access to domain context, so `before`/`after` are semantically rich.

**Cons**:
- Completeness rests on discipline. A new code path that forgets the call
  produces a silent gap, which is the exact failure mode §9 exists to prevent.
- Needs explicit serialisation to keep the chain linear.

### Option 2: PostgreSQL triggers on every audited table

**Description**: `AFTER INSERT OR UPDATE OR DELETE` triggers write audit rows
from `OLD`/`NEW`, inside the same transaction by construction.

**Pros**:
- Completeness is structural: nothing that writes the table can bypass it, not
  even a direct `psql` session.
- Same-transaction semantics are free.

**Cons**:
- The actor and the intent are not available to the trigger unless passed
  through a session variable, which reintroduces a discipline requirement for
  *attribution* even though *completeness* is guaranteed.
- Business-level events (§17's pipelines: `P-SHIP`, `P-ELN-SIGN`) do not map
  one-to-one onto row changes, so a trigger-only trail is at the wrong altitude
  for §9's export.
- Chain sequencing still needs serialisation.

### Option 3: Triggers for completeness plus an explicit domain event stream

**Description**: Both. Triggers guarantee that no row change is unrecorded.
The unit-of-work helper additionally emits a semantic domain event
(`sample.shipped`, `notebook.signed`) in the same transaction. Both feed one
append-only `audit_event` table. Chain linearity is enforced by taking a
PostgreSQL advisory lock on the chain before assigning `prev_hash`, so the
sequence number and the hash are assigned under mutual exclusion.

**Pros**:
- Completeness is structural and attribution is explicit.
- The trail carries both the row-level truth and the business meaning §9's
  export and §17's pipelines need.
- Advisory-lock serialisation makes the chain provably linear without
  serialising the whole transaction.

**Cons**:
- Two mechanisms to understand and keep consistent.
- The advisory lock is a serialisation point on the write path.

## Decision Outcome

**Chosen Option**: Option 3 — triggers for completeness, domain events for
meaning, advisory-lock serialisation for chain linearity.

**Rationale**:

- Option 1 makes the project's central integrity guarantee depend on nobody ever
  forgetting a call. Over a long-running multi-session project that is not a
  guarantee, it is a hope.
- Option 2 alone cannot express `P-SHIP` or `notebook.signed` at the altitude
  §9's export and §16.2's outbox both consume.
- The advisory lock is the smallest mechanism that makes the chain linear. The
  alternative — `SERIALIZABLE` isolation for every write — costs far more and
  buys guarantees the rest of the system does not need.
- Measured against §14: the lock is held for the duration of one hash
  computation and one insert. At 100 concurrent users this is not the
  bottleneck; if it ever becomes one, the chain can be partitioned per project
  with a per-project genesis, which the schema allows for from the start.

## Consequences

### Positive

- No domain write can escape the trail, including a direct database session.
- Tampering is detectable: altering or deleting an event breaks the chain from
  that point, and the daily checkpoint bounds how far back verification must go.
- `actor_type` distinguishes `human`, `mcp` and `system`, satisfying §10.

### Negative

- The advisory lock serialises hash assignment. This is a deliberate, measured
  cost and must be covered by a load test against §14's targets, not assumed to
  be acceptable.
- Two write paths into one table means the schema must tolerate both row-level
  and semantic events. The `kind` discriminator carries that.

### Neutral

- The audit table is append-only by grant, not by convention: the application
  role receives `INSERT` and `SELECT` and no `UPDATE` or `DELETE`. The auditor
  role receives `SELECT` only, satisfying §11 and CON-006 at the database level
  rather than in application code.

## Implementation Notes

- `prev_hash` of the genesis event is the all-zero digest.
- The hashed payload is a canonical JSON serialisation with sorted keys and no
  insignificant whitespace, so the digest is reproducible across languages.
  Canonicalisation is itself a test target; an ambiguous encoding silently
  destroys the chain's value.
- The daily checkpoint (§9) stores the head hash and sequence number, signed
  with a key rotated by `P-KEY-ROTATE` (§17.4).
- Verification walks backwards to the most recent checkpoint, not to genesis.

## References

- `specs/source/spezifikation-extract.md` §2, §3, §9, §10, §11, §16.1, §17.4
- Memory: `FR-007`, `FR-011`, `FR-020`, `FR-040`, `FR-041`, `FR-042`, `FR-046`,
  `CON-006`, `CON-008`
