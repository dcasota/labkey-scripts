---
agent: dev
---
# Dev team flow step

Implement the next backlog item, end to end.

## Before writing code

1. `tools/memory.py list backlog --where "status='todo'" --brief` — take the
   lowest `seq` whose dependencies are `done`.
2. Read its task file and the FRD it serves.
3. Read `AGENTS.md` and `memory.md`.
4. `tools/memory.py set backlog PR-NNN status in-progress`.
5. Create the branch: `pr-NNN-<slug>`.

## While writing code

- **Verify, never assume.** Any claim about how LabKey behaves must be backed by
  the source under `/root/scicore` or by an actual HTTP call against the running
  server, and recorded with `tools/memory.py add verification`.
- Never modify `/root/scicore` or the running deployment except through
  `scripts/`. Leave `/root/install-labkey-sleepdrive-lab.sh` and the LabKey
  `SleepDrive-Lab` project alone.
- No secret, credential, key or token is ever written into the repository.
  Credentials come from the environment variables listed in `memory.md`, and a
  script that is missing one must fail loudly rather than guess.
- Tests accompany the code in the same pull request.
- **If a significant architectural decision is missing, stop.** Hand back to
  `@architect` for an ADR. Do not decide it inside the implementation.

## Before finishing

- Every acceptance-criteria checkbox in the task file is ticked, or the item is
  not done.
- `tools/memory.py check` passes.
- Append a `JOURNAL.md` entry.
- `tools/memory.py set backlog PR-NNN status review`.
