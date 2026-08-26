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

---

## [2026-08-26T04:00:00Z] Harvest LabKey's release notes and documentation for specifications

- **Operation**: research
- **Branch**: `pr-001b-labkey-doc-harvest`
- **Question**: the operator guide made plain that the sample manager is still
  unimplemented and under-specified. LabKey has been building this exact system
  for nineteen years and publishes what it built and when. That is a
  specification source nobody had read.
- **Produced**: `docs/labkey-release-notes-survey.md` (2004 lines) and
  `docs/premium-feature-gap.md` (565 lines); 19 requirements, 16 backlog
  items, 26 feature rows, 16 research findings and 10 verifications in the
  memory database.
- **Coverage**: 61 releases enumerated, 60 release-notes pages fetched, 1 with
  no page (2.0). 3 LIMS pages fetched, 83 release sections, 415 items. 265
  documentation pages fetched, 17 soft-404s. Zero rate limiting; zero fetch
  failures.

- **Method note**: the release inventory is a LabKey *list*, so it was queried
  through `query-selectRows.api` rather than scraped — the same query the
  Previous Releases page makes. Three assumptions in the plan turned out false
  and are recorded as failed verifications rather than quietly worked around:
  V-035, the advertised `releaseNotes{MM}` URL pattern 404s for all ten releases
  before 10.1; V-034, the LIMS notes are one consolidated page and not
  per-release pages; V-039, a missing LabKey wiki page returns **HTTP 200** with
  the body "This page has no content.", so status codes cannot be trusted to
  establish existence. Nine of the ten missing pages were recovered by probing
  alternate names.

- **Key finding**: **sample management is a separate product, not a premium
  feature of LabKey Server.** The freezer, workflow queue, notebook, picklist,
  finder, timeline and status UI live in the `/limshelp` wiki, are badged
  against Sample Manager and LIMS editions, and the complete badge vocabulary
  is `SM Starter`, `SM Professional`, `LIMS Starter`, `LIMS Enterprise`,
  `Biologics LIMS` — **there is no Community chip anywhere in that container**.
  ADR-0001's "there is no CE substrate to extend" is now confirmed from
  LabKey's own documentation, not inferred from its build files.

- **Second finding**: Community Edition has been **losing** ground. The Specimen
  Repository was removed from all standard distributions in 21.3 ("Do not
  upgrade a Community Edition if you want to continue using specimen"),
  Specialty Assays in 21.7, FreezerPro and SampleMinded integration in 25.3.
  Since March 2025, CE has had no freezer capability from any direction. What CE
  gained instead is audit and API hygiene — forced detailed audit on samples
  (25.11), per-folder audit roles (26.3), role-restricted API keys (26.7) —
  every one of which the publish bridge depends on, and none of which is a
  sample-management feature.

- **Third finding, from the negatives**: across 60 release-notes pages the
  strings `hash` and `tamper` appear **zero** times, and `21 CFR` / `Part 11` /
  `GxP` / `GMP` appear zero times in the server notes and **once** in the 83
  LIMS sections — as a warning that a convenience feature may *break* Part 11
  compliance. LabKey documents no point-in-time recovery and no restore drill at
  any price. ADR-0003 and NFR-006 have no prior art; they also have no
  compatibility to preserve.

- **Reconciliation (Part 3 against Part 1)**: the LIMS notes are monthly and the
  server notes four-monthly, so ten capabilities carry two different version
  numbers; the LIMS date is the earlier one in every case (freezer management
  21.1 not 21.3, aliquots and picklists 21.6 not 21.7, timeline 20.5 not 20.7).
  Part 1 also missed twenty capabilities entirely — workflow-integrated storage
  actions, the `CheckedOut` column, identifying fields, required lineage,
  restricted lineage nodes, storage-unit barcodes and the removal of
  cross-folder import among them. And Part 1 **over-claimed the paywall on
  storage and under-claimed it on workflow**: freezer management and check-out
  are the *cheapest* paid tier; workflow, the ELN and folders are one above;
  template actions and Part 11 signatures are two and three above.

- **Scope discipline**: fourteen LabKey capabilities are flagged in
  `labkey-release-notes-survey.md` §7 as questionable rather than silently
  included or excluded — freeze/thaw counting, plate campaigns, media and
  recipes, the bioregistry, access recertification, saved finder reports,
  offline box printing, BarTender, and others. Four more are flagged in
  `premium-feature-gap.md`: read-access auditing, multi-factor authentication
  for signatories, malware scanning of uploads, and cross-folder moves of
  audited objects. None was turned into a requirement.

- **Honesty about evidence**: both new pages are `doc`-grade by
  `standards/general/verification.md`, the weakest tier, and say so in their
  first paragraph. Five behavioural questions the release notes raise and cannot
  answer are listed in survey §6.4 and scheduled as PR-039 rather than assumed.

- **Status**: Success — `make check` green, 251 unit tests passing, memory
  integrity OK
