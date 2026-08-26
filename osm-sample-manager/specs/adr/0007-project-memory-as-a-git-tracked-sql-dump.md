# ADR-0007: Project Memory Is A Git-Tracked SQL Dump

**Date**: 2026-08-26
**Status**: Accepted

## Context

This project runs across many sessions, each of which starts without the
previous one's context. Durable knowledge — requirements traced to spec
sections, verified facts about LabKey CE, decisions and their rationale, the
backlog and its status — has to survive in a form that is both machine-queryable
and reviewable.

The brief asked for SQLite and left the commit strategy open, requiring the
choice to be stated.

## Decision Drivers

- A later session must be able to ask precise questions ("which requirements in
  iteration I2 have no backlog item?") without reading every document.
- A reviewer must be able to see what knowledge changed in a pull request.
- The store must be reconstructible byte-for-byte, or it is not a deterministic
  build input.
- Hand-editing must be discouraged, because the schema carries constraints that
  a hand edit would bypass.

## Considered Options

### Option 1: Commit the binary `.db`

**Description**: Track `.sdd/memory.db` directly.

**Pros**:
- Single artifact; clone and query immediately.
- No rebuild step.

**Cons**:
- No reviewable diff. A pull request that changes a decision's rationale is
  indistinguishable from one that deletes half the backlog.
- Binary merge conflicts are unresolvable in practice; the loser's knowledge is
  simply lost.
- SQLite files are not byte-stable across writes even for identical content
  (page ordering, freelists), so the repository churns.

### Option 2: Commit only markdown, no database

**Description**: Keep everything in `specs/` and `docs/` as prose.

**Pros**:
- Maximally reviewable and diffable.
- No tooling.

**Cons**:
- Cross-cutting queries become full-text searches over prose, which is exactly
  what makes a later session re-derive knowledge instead of looking it up.
- No constraints: nothing prevents a dangling dependency or a duplicated id.
- Traceability degrades into hyperlinks nobody validates.

### Option 3: Commit a deterministic SQL dump, treat the binary as derived

**Description**: `.sdd/memory.sql` is tracked and authoritative;
`.sdd/memory.db` is git-ignored and rebuilt from the dump.

**Pros**:
- Reviewable: every knowledge change is a text diff of `INSERT` statements.
- Queryable: rebuild and run SQL.
- Merge conflicts are ordinary text conflicts, resolvable line by line.
- Deterministic: fixed table order and fixed row order make the dump
  byte-identical for identical content.
- The rebuild is a genuine build step, so a stale dump is detectable.

**Cons**:
- Two artifacts and a rebuild step to explain.
- The dump must be regenerated on every write or it goes stale silently.

## Decision Outcome

**Chosen Option**: Option 3 — deterministic SQL dump tracked, binary derived.

**Rationale**:

- Reviewability is the deciding property. Knowledge that changes invisibly is
  knowledge nobody can trust, and this database is meant to be the thing later
  sessions trust instead of re-deriving.
- The staleness objection is answerable in code rather than in discipline: every
  mutating CLI command rewrites the dump, and `tools/memory.py check`
  regenerates it and fails if the tracked copy differed.
- Option 1's merge behaviour is disqualifying for a repository that will
  eventually take contributions.

## Consequences

### Positive

- A pull request shows exactly which requirement, decision or backlog item
  changed.
- The database can be destroyed and rebuilt at any time; it holds no state the
  dump does not.
- The CLI enforces id patterns, foreign keys and enum constraints, so the
  knowledge base stays internally consistent.

### Negative

- Contributors must use the CLI. Hand-editing either file is a mistake the
  tooling can detect but not prevent.
- The dump grows monotonically with the knowledge base; at very large sizes the
  diff stops being pleasant. This is not a concern at the scale this project
  will reach.

### Neutral

- `OSM_MEMORY_DB` and `OSM_MEMORY_DUMP` allow both paths to be relocated, which
  makes the tool testable against a throwaway database.

## Implementation Notes

- Determinism comes from a fixed table order and an explicit `ORDER BY` per
  table, both declared in `tools/memory.py`. Adding a table means adding its
  ordering key, and the tool will not silently omit it.
- If `.sdd/memory.db` is absent, the CLI rebuilds it from the dump on first use,
  so a fresh clone needs no ceremony.
- `tools/memory.py check` is the pre-commit gate: dangling dependencies,
  duplicate sequence numbers, unknown references and a stale dump all fail it.

## References

- `memory.md`
- `tools/memory.py`
