# AGENTS.md — the briefing for any session working on OSM

Read [`memory.md`](memory.md) first. This file consolidates `standards/` into
the rules that apply to every change. It is regenerated when `standards/`
changes (`/generate-agents`).

## 1. The framing, which is easy to get wrong

**OSM is the system of record. LabKey CE is a downstream publish target.**

OSM is not a LabKey module, not a LabKey UI clone, and does not depend on LabKey
to function. The specification says so four times in §1 alone. If a change makes
OSM depend on LabKey being available, it is wrong. See ADR-0001.

## 2. Verify, do not assume

This project's characteristic failure is a plausible but wrong belief about
LabKey Community Edition. Five capabilities look present and enforce nothing:

| Looks like | Actually |
| --- | --- |
| Sample status | `isOperationPermitted()` returns `true` unconditionally; **no rule is enforced** |
| PHI column tagging | No `ComplianceService` registered; **masks nothing** |
| Freezer support | `InventoryService.get()` returns `null`; columns silently absent |
| MCP server | `NoopMcpService`, `isEnabled()` false |
| Barcode field type | Blocked only in JavaScript; the API creates working ones |

So: **any claim about LabKey behaviour must be backed by source under
`/root/scicore` or by a real HTTP call**, and recorded:

```bash
tools/memory.py add verification --id V-nnn --claim "..." \
    --method source|http|shell|doc --command "..." --result pass|fail|partial
```

A `fail` is as valuable as a `pass`. Record it; do not retry until the answer is
convenient. Check `docs/labkey-ce-ground-truth.md` before verifying something
that may already be known.

## 3. Security

- **No secret, credential, key or token enters the repository. Ever.**
  Credentials come from the environment (ADR-0008). There are no defaults — a
  missing variable aborts with a message naming it. Never pass a credential as a
  command-line argument; use the environment, because arguments are visible in
  the process table.
- **Never log a credential**, at any level. Log the URL and the status code.
- **Least privilege**: the LabKey bridge uses an API key restricted to
  `EditorWithoutDelete`. Database roles get `INSERT`/`SELECT` on audit tables and
  no `UPDATE`/`DELETE`. The auditor role gets `SELECT` only.
- **Validate on the server.** Client-side validation is a convenience; the
  boundary is the only place that counts.
- **Every new domain table gets a row-level security policy.** A table without
  one fails a schema test, so the protection cannot be forgotten.
- **Injection surfaces**, all of which appear in this project:
  - *LabKey SQL*: never build a query by string concatenation from user input.
    Parse filter expressions into a typed structure. LabKey SQL supports
    `USERID()`, `||`, `COALESCE`, joins and subqueries — all of which a hostile
    filter could exploit if it reached the SQL text.
  - *CSV and file import*: validate the declared content type rather than
    trusting it; bound the size and row count; report every rejected row with
    its line number; neutralise formula injection so a cell beginning with `=`
    or `@` cannot execute when the file is later opened.
  - *Barcode input*: scanned input is untrusted. Bound its length, validate its
    characters, never interpolate it into a query. A barcode that does not
    resolve returns 404 rather than an error that reveals whether the id exists
    in another project.
  - *Prompt injection*: the assistant tool allowlist is bound to the session at
    authentication time and is never derived from document content. The
    retrieval corpus is restricted **at index time**, not filtered at query time.
- **Auditability**: every write is audited in the same transaction that performs
  it. If a code path can write without auditing, that is a defect (ADR-0003).

## 4. Resilience

- **Idempotent**: every script and installer is safe to re-run. Creating
  something that exists is success, not an error.
- **No silent failures**: a failed step is recorded and surfaced. `|| true` is
  acceptable only where the outcome is then explicitly checked.
- **Deterministic rebuilds**: dependencies are pinned; the memory dump is
  byte-stable; migrations are reversible.
- **Fail loudly on a missing precondition** rather than continuing with a guess.
  A migration that cannot create `btree_gist` aborts; it does not carry on.

## 5. Boundaries — do not cross these

- Do not modify anything under `/root/scicore` or the running LabKey deployment
  **except through this project's `scripts/`**.
- `/root/install-labkey-sleepdrive-lab.sh` and the LabKey `SleepDrive-Lab`
  project belong to different work. **Leave them alone.**
- The repository has **no git remote**, deliberately, until `GITHUB_TOKEN` is
  supplied. Do not add one.

## 6. Working method

1. Take the lowest-`seq` backlog item whose dependencies are `done`:
   `tools/memory.py list backlog --where "status='todo'" --brief`.
2. `tools/memory.py set backlog PR-nnn status in-progress`; branch `pr-nnn-slug`.
3. Read the task and the ADRs it cites.
4. Implement with tests in the same change. Test the **denials**, not only the
   successes — a role test that only proves access works has tested nothing.
5. **If a significant architectural decision is missing, stop.** Hand back for
   an ADR. Do not decide it inside the implementation.
6. Before finishing: every acceptance checkbox ticked, `tools/memory.py check`
   green, `tools/render_backlog.py --check` green, a `JOURNAL.md` entry
   appended, status set to `review`.

## 7. Conventions

- **Python**: type hints throughout; `Decimal` for every sample amount (LabKey
  stores these as floats and the drift is real); explicit transaction boundaries
  through the unit-of-work helper, which is the only sanctioned way to open a
  write.
- **Commits**: imperative subject under 72 characters, a body explaining *why*,
  authored `Daniel Casota <dcasota@gmail.com>`, ending with
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- **LabKey HTTP**: bootstrap the session via `login-whoAmI.api`; do not follow
  redirects; do not use `curl -f` — 4xx bodies are needed; skip TLS verification
  only for loopback. The import action is `query-import.api`, not
  `query-importData.api`. `experiment-saveMaterials.api` does not exist.
