# Open Sample Manager (OSM)

An open-source sample-lifecycle system: registration, freezer map, job queue,
electronic lab notebook, faceted search, tamper-evident audit, a REST and MCP
API, and downstream publishing into LabKey Community Edition.

> **OSM is the system of record. LabKey CE is a publish target.**
> OSM is not a LabKey module and not a reimplementation of the LabKey Sample
> Manager interface. See
> [`specs/adr/0001-osm-is-the-system-of-record.md`](specs/adr/0001-osm-is-the-system-of-record.md).

Licence: Apache-2.0 for code, CC-BY-4.0 for documentation.

## Why this exists

LabKey Community Edition provides the sample *data model* and almost none of the
sample *management application*. Freezer mapping, status enforcement, check-in
and check-out, picklists, the sample finder, workflow jobs and the ELN are all
commercial, starting at USD 6,540 per year for five users.

Of 34 capabilities catalogued in [`docs/gap-analysis.md`](docs/gap-analysis.md),
LabKey CE provides 7 natively, 5 partially, and 22 not at all.

Five of those capabilities are worse than absent — they look present and enforce
nothing. `SampleStatusService.isOperationPermitted()` returns `true`
unconditionally, so CE enforces no sample status rules; PHI column tagging masks
nothing because no compliance service is registered. Both are documented with
their evidence in [`docs/labkey-ce-ground-truth.md`](docs/labkey-ce-ground-truth.md).

## Start here

| If you want to | Read |
| --- | --- |
| Understand the project and its knowledge base | [`memory.md`](memory.md) |
| Know what LabKey CE actually does | [`docs/labkey-ce-ground-truth.md`](docs/labkey-ce-ground-truth.md) |
| See what OSM must build and why | [`docs/gap-analysis.md`](docs/gap-analysis.md) |
| Read the product requirements | [`specs/prd.md`](specs/prd.md) |
| See the decisions and their rationale | [`specs/adr/`](specs/adr/) |
| Pick up the next piece of work | [`docs/backlog.md`](docs/backlog.md) |
| Follow the working rules | [`AGENTS.md`](AGENTS.md) |

## Quick start

```bash
# The memory database is the project's knowledge base.
tools/memory.py rebuild        # .sdd/memory.sql -> .sdd/memory.db
tools/memory.py stats
tools/memory.py list backlog --brief

# Talking to LabKey needs credentials from the environment. Never hardcode them.
export LK_URL=https://127.0.0.1:8443
export LK_USER=...
export LK_PASSWORD=...          # or export LK_APIKEY=... instead
scripts/verify_labkey.py
```

No credential has a default value. A script missing one fails and names it.
See the environment variable table in [`memory.md`](memory.md).

## Method

This project follows Spec-Driven Development. Artefacts live in `specs/`, the
workflow is defined in `.github/prompts/`, and the agent roles in
`.github/agents/`. The chain runs:

```
spec .docx  ->  memory requirements  ->  PRD REQ-n  ->  FRD  ->  task  ->  code
```

Every link is recorded in the memory database, so
`tools/memory.py show FR-029` answers "why does this code exist?" in one call.

## Repository layout

```
memory.md               entry point: the knowledge base and the house rules
.sdd/memory.sql         the knowledge base itself (deterministic, tracked)
tools/                  memory.py, render_backlog.py
specs/                  prd.md, adr/, features/, tasks/, source/
docs/                   ground truth, gap analysis, backlog
standards/              the engineering rules this project holds itself to
scripts/                the only sanctioned way to touch a LabKey deployment
src/osm/                implementation
tests/                  tests
```

## Status

Bootstrap complete: 97 requirements traced to their specification sections,
18 verifications, 15 research findings, 8 decisions, a 34-row gap inventory and
a 38-item pull-request backlog. Implementation begins at PR-001.
