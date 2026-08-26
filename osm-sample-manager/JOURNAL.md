# Journal

Append-only. Every session that changes state adds an entry. Newest last.
Timestamps are ISO-8601 UTC.

---

## [2026-08-26T00:00:00Z] Project bootstrap

- **Operation**: bootstrap
- **Inputs**: `OSM_Sample_Manager_Spezifikation.docx` v1.1; the SDD methodology
  from `dcasota/photonos-scripts` and `sitoader/SDD-book-tracking-app`; the
  LabKey CE 26.7.5 enlistment at `/root/scicore`; the running server at
  `https://127.0.0.1:8443`; the user's `install-labkey-*.sh` scripts.
- **Produced**: git repository with three commits; memory database with 97
  requirements, 15 research findings, 18 verifications, 8 decisions, a 34-row
  feature/gap inventory, a 38-item backlog and 97 traceability edges; SDD
  artefacts (`specs/prd.md`, `specs/adr/0001-0008`, `specs/tasks/README.md`,
  `.github/agents/`, `.github/prompts/`); research output
  (`docs/labkey-ce-ground-truth.md`, `docs/gap-analysis.md`).
- **Key finding**: the brief asked for "a Sample Manager for LabKey CE"; the
  specification requires a standalone system with LabKey downstream. The
  specification governs. ADR-0001 records the reasoning and the evidence.
- **Second finding**: five LabKey CE capabilities appear present and enforce
  nothing. `SampleStatusService.isOperationPermitted()` returns `true`
  unconditionally and PHI tagging masks nothing. Both would have produced a
  wrong implementation if assumed rather than verified.
- **Status**: Success

---

## [2026-08-26T01:00:00Z] PR-001 — LabKey client library and verification harness

- **Operation**: implement
- **Branch**: `pr-001-labkey-client`
- **Produced**: `src/osm/labkey/{config,client}.py`, `scripts/verify_labkey.py`,
  `tests/test_labkey_{config,client,integration}.py`, `pyproject.toml`, `Makefile`.
- **Tests**: 78 unit (no network) and 11 integration against the live server,
  all passing. The integration tests pin the ground-truth claims, so a LabKey
  upgrade that changes one breaks a test rather than leaving the documentation
  quietly wrong.
- **Live verification**: 8 of 8 probes pass against `https://127.0.0.1:8443`.
  Recorded as V-019, V-020, V-021.
- **Note**: the login response nests the principal under `user`, unlike
  `login-whoAmI.api` which reports it at the top level. Found because the
  session log said "unidentified" after a successful login.
- **Secret scan**: no credential literal appears in any tracked file.
- **Status**: Success — awaiting review

---

## [2026-08-26T02:00:00Z] Test hardening across the bootstrap

- **Operation**: test + fix
- **Branch**: `pr-001a-test-hardening`
- **Scope**: the whole bootstrap, not only PR-001. The project tooling had
  become load-bearing — every later session reads the knowledge base through
  `tools/memory.py` — while being the only part with no tests of its own.
- **Added**: 184 tests across four new files. `test_memory_cli.py` (68),
  `test_memory_invariants.py` (50), `test_no_secrets.py` (23),
  `test_render_backlog.py` (20), plus 23 failure-path tests added to the
  existing LabKey config suite. Total 251 unit and 11 integration.
- **Issues found and fixed** (all five found by a test, none by inspection):
  1. `check` did not fail on a requirement with no traceability link.
  2. `check` validated only `backlog` traceability edges, so a dangling
     `decision`, `feature` or `verification` edge passed.
  3. `link` raised an uncaught traceback on an unknown requirement.
  4. `set` raised an uncaught traceback on a constraint violation.
  5. A foreign-key failure was reported as "use --replace to overwrite",
     which is misleading — replacing a row cannot make a missing parent exist.
- **Also**: added a dependency-ordering check to the gate; added `--out-dir`
  to the renderer so drift can be tested in isolation; made TLS relaxation
  towards a non-loopback host emit a warning naming the host; turned warnings
  into errors under pytest with one documented exception.
- **Note**: the secret scanner is proven to fire on eight planted secrets and
  proven not to fire on eight safe patterns. A gate that cannot fail is not a
  gate.
- **Status**: Success — 262 tests passing, `make check` green

---

## [2026-08-26T03:00:00Z] Operator and administrator guide

- **Operation**: document
- **Branch**: `pr-001a-test-hardening`
- **Produced**: `tools/build_guide.py` and the Word document it generates,
  `docs/OSM-Sample-Manager-Guide.docx` (13 sections, 38 tables, roughly 34
  pages), plus `make docs` and `make docs-check` targets.
- **Method**: the guide is generated, not hand-written. The project version
  comes from `pyproject.toml`, the revision from git, and the backlog, decision
  register, capability rollups and knowledge-base row counts from the memory
  database, so the document cannot quietly disagree with the repository. Prose
  is held in the generator and reviewed as source.
- **Determinism**: every timestamp in the package is pinned to the HEAD commit
  date and the zip is rewritten with fixed member timestamps in sorted order,
  so two builds from one commit are byte-identical. `--check` is therefore
  meaningful and is wired into `make check` as `docs-check`, skipping with a
  message when `python-docx` is absent, matching the `lint`/`types` pattern.
- **Note**: pinning to HEAD makes the naive freshness check self-defeating —
  committing the guide moves HEAD, so the document is stale the instant it
  lands. `--check` therefore reads the revision, branch and date back out of
  the document's own properties and rebuilds with them, comparing content
  rather than provenance. Every row count, backlog row and decision still has
  to match; only the revision label may be older.
- **Note**: writing the guide surfaced five places where the repository's own
  documentation disagrees with the code. They are recorded in appendix 11.7
  rather than silently corrected: `README.md` still says 18 verifications (29
  now); `LK_TIMEOUT` is read by `src/osm/labkey/config.py` but appears in
  neither `memory.md` nor `.env.example`; `memory.md` references a
  `specs/README.md` that does not exist; `.github/prompts/verify.prompt.md`
  references a `scripts/labkey_client.py` that does not exist; and
  `specs/features/` is empty, so no FRD has been written.
- **Note**: the secret scanner fired on `props.author = "..."` in the
  generator, because `author` matches its `auth*` rule. Fixed by moving the
  string to a module constant rather than by broadening the pattern or growing
  the allowlist, which is what the scanner's own guidance asks for.
- **Status**: Success — `make check` green, 251 unit tests passing
