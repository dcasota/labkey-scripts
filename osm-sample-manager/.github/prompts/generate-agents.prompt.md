---
agent: devlead
---
# Dev team flow step

Consolidate `standards/` into `AGENTS.md`.

`AGENTS.md` is the single briefing an implementation session reads. It must be
complete enough that a session which has read only `memory.md` and `AGENTS.md`
can work correctly without re-reading every standard.

Regenerate it whenever `standards/` changes.

## Required before

`/plan` and `/implement`. Planning or implementing without a current
`AGENTS.md` is out of process.

## Contents

- The project framing: OSM is the system of record, LabKey CE is downstream.
- The verification rule and how to record verifications.
- The security rules: no secrets, least privilege, server-side validation,
  auditability, injection surfaces.
- The resilience rules: idempotent scripts, explicit error handling, no silent
  failures, deterministic rebuilds.
- Language and framework conventions, from `standards/`.
- The boundaries: what must not be touched.
