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
