# OSM project memory

This is the **entry point** for every session working on Open Sample Manager
(OSM). Read this file first, then query the memory database. Do not re-derive
knowledge that is already recorded here.

## What the project is

OSM is an open-source sample-lifecycle system specified in
`OSM_Sample_Manager_Spezifikation.docx` v1.1 (21 Aug 2026, Universität Basel ·
Biomed / Open LIMS). A verbatim-structure extraction lives in
`specs/source/spezifikation-extract.md`.

The single most important framing fact, and the one most often got wrong:

> **OSM is the system of record. LabKey CE is a downstream publish target.**
> The spec says *"Unabhängig von LabKey-Produkten"*, *"Kein LabKey-UI-Klon"*,
> *"LabKey ist Downstream"* (§1). OSM is **not** a LabKey module and **not** a
> reimplementation of the LabKey Sample Manager UI. See `specs/adr/ADR-001-*`.

## The memory database

| Path | Role |
| --- | --- |
| `.sdd/memory.sql` | **Source of truth**, tracked in git. Deterministic SQL dump. |
| `.sdd/memory.db` | Derived SQLite binary. **Git-ignored**, rebuilt on demand. |
| `tools/memory.py` | The only supported way to read or write the database. |

### Why the dump is committed and the binary is not

A binary SQLite file produces no reviewable diff, merges badly, and makes it
impossible to see in a pull request what knowledge changed. The dump is emitted
with a fixed table order and a fixed row order, so the same database always
yields byte-identical text. Every mutating CLI command rewrites the dump
automatically, and `tools/memory.py check` fails if the tracked dump has drifted
from the database. The binary is reproducible at any time:

```bash
tools/memory.py rebuild     # .sdd/memory.sql -> .sdd/memory.db
```

If `.sdd/memory.db` is missing, the CLI rebuilds it from the dump on first use.

### Schema

Nine tables. Run `tools/memory.py stats` for row counts.

| Table | Holds | ID form |
| --- | --- | --- |
| `requirements` | Requirements extracted from the spec, with the spec section they came from | `FR-nnn`, `NFR-nnn`, `CON-nnn`, `PRO-nnn` |
| `research` | Research findings, each pinned to evidence (file path, URL, or API action) | `RF-nnn` |
| `decisions` | Architecture Decision Records, mirrored to `specs/adr/` | `ADR-nnn` |
| `features` | Feature/gap inventory: commercial Sample Manager vs LabKey CE vs OSM | `FEAT-nnn` |
| `backlog` | Ordered PR backlog with acceptance criteria and dependencies | `PR-nnn` |
| `tasks` | Tasks belonging to a backlog item | `T-nnn` |
| `verifications` | How a claim about the environment was actually checked | `V-nnn` |
| `traceability` | requirement → artifact edges | (composite) |
| `meta` | Schema version and provenance | — |

`requirements.kind` is one of `functional`, `nonfunctional`, `constraint`,
`prohibition`. Prohibitions matter: the spec forbids specific things (§18.2,
§16.2) and those are requirements too.

`features.ce_support` records whether LabKey CE gives a capability `native`ly,
`partial`ly, only via `custom` work, or not at all (`absent`). `features.gap` is
the OSM implementation effort.

### Querying

```bash
tools/memory.py stats                       # rollups
tools/memory.py list backlog --brief        # the PR queue in order
tools/memory.py list requirements --where "iteration='I2'"
tools/memory.py show PR-001                 # everything about one id
tools/memory.py query "SELECT id,name,ce_support,gap FROM features WHERE gap='high'"
tools/memory.py check                       # integrity gate; exit 2 on problems
```

`query` accepts read-only `SELECT`/`WITH` only. Use `add` and `set` to mutate.

### Writing

```bash
tools/memory.py add research --id RF-042 --topic "..." --finding "..." \
    --evidence-kind http --evidence-ref "POST /home/query-getSchemas.api"
tools/memory.py add verification --id V-007 --claim "..." --method http \
    --command "..." --result pass
tools/memory.py set backlog PR-001 status done
tools/memory.py link --req FR-003 --kind backlog --to PR-004
tools/memory.py batch seed.txt              # many statements, one dump
```

**Never hand-edit `.sdd/memory.sql` or `.sdd/memory.db`.** The CLI enforces ID
patterns, foreign keys and enum constraints that a hand edit would bypass.

## House rules recorded from the project brief

1. **Verify, do not assume.** Every claim about LabKey behaviour must be backed
   by source under `/root/scicore` or by a real HTTP call against the running
   server, and recorded in `verifications`.
2. **No secrets in the repo, ever.** See the environment variables below.
3. Do not modify `/root/scicore` or the running deployment except through this
   project's own scripts under `scripts/`.
4. `/root/install-labkey-sleepdrive-lab.sh` and the LabKey `SleepDrive-Lab`
   project belong to a different piece of work. Leave them alone.

## Environment variables

Nothing below has a default that is a real credential. Scripts fail loudly when
a required variable is unset rather than guessing.

| Variable | Purpose | Required for |
| --- | --- | --- |
| `LK_URL` | LabKey base URL. Defaults to `https://127.0.0.1:8443`. | LabKey scripts |
| `LK_USER` | LabKey login (email or display name). | LabKey scripts, unless `LK_APIKEY` |
| `LK_PASSWORD` | LabKey password. **Never commit.** | LabKey scripts, unless `LK_APIKEY` |
| `LK_APIKEY` | LabKey API key; preferred over user/password. Takes precedence. | LabKey scripts |
| `LK_CONTEXT` | Servlet context path, `auto` to probe. | LabKey scripts |
| `LK_INSECURE` | `1` to skip TLS verification (self-signed loopback certs). | LabKey scripts |
| `OSM_MEMORY_DB` | Override the memory database path. | `tools/memory.py` |
| `OSM_MEMORY_DUMP` | Override the dump path. | `tools/memory.py` |
| `HUGGINGFACE_API_KEY` | HuggingFace inference token, for the §18 assistant work. Not yet supplied. | I6 assistant |
| `HUGGINGFACE_MODEL_ID` | Model to call. Not yet supplied. | I6 assistant |
| `GITHUB_TOKEN` | GitHub PAT for pushing and opening PRs. Not yet supplied. | release tooling |

The naming for `LK_*` deliberately matches the user's existing scripts
(`/root/install-labkey-*.sh`) so a single exported environment drives both.

The repository has **no git remote** on purpose. It will be added once
`GITHUB_TOKEN` is supplied.

## Where things live

```
specs/                  SDD artefacts (see specs/README.md for the methodology)
  prd.md                Product Requirements Document
  adr/                  Architecture Decision Records
  features/             Feature Requirements Documents, one per capability
  tasks/                Technical task specifications
  source/               Extraction of the original .docx specification
docs/                   Research output: gap analysis, LabKey ground truth
  backlog.md            Human-readable rendering of the PR backlog
standards/              Engineering guidelines this project holds itself to
tools/                  memory.py and other project tooling
scripts/                The only sanctioned way to touch the LabKey deployment
src/                    Implementation
tests/                  Tests
```
