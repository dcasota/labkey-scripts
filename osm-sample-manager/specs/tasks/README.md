# Open Sample Manager — Technical Tasks

Generated from the memory database by `tools/render_backlog.py`.

Each pull request in the backlog is one task. The full acceptance criteria
are in `docs/backlog.md` and in the memory database; this page is the phase
index and the traceability matrix.

## Task Overview

### Phase I0: Foundations (PR-001–PR-008)

**Acceptance gate**: Auth, audit and OpenAPI. Done when the hash chain verifies.

**PR-001 — LabKey client library and verification harness**

- A reusable, credential-safe Python client for the LabKey HTTP API, plus the harness that records environment facts into the memory database. Everything that later talks to LabKey builds on this, and every future claim about LabKey behaviour is verified through it.
- **Dependencies**: none
- **Complexity**: M (3-5 days)
- **Status**: review

**PR-002 — Python project skeleton, tooling and quality gates**

- pyproject with pinned dependencies, ruff, mypy, pytest with coverage, and a single make target that runs every gate. Establishes the deterministic rebuild the project promises.
- **Dependencies**: PR-001
- **Complexity**: S (1-2 days)
- **Status**: todo

**PR-003 — PostgreSQL schema bootstrap and migrations**

- Alembic wired up, the btree_gist extension installed, database roles for application and auditor created with least privilege, and an idempotent bootstrap script.
- **Dependencies**: PR-002
- **Complexity**: M (3-5 days)
- **Status**: todo

**PR-004 — Tamper-evident audit hash chain**

- Implements ADR-0003: triggers for completeness, semantic domain events for meaning, advisory-lock serialisation for chain linearity, canonical JSON hashing.
- **Dependencies**: PR-003
- **Complexity**: M (3-5 days)
- **Requirements**: FR-002, FR-007, FR-011, FR-020, FR-040
- **Spec sections**: spec:§1, spec:§1,§9, spec:§2, spec:§3, spec:§9
- **Status**: todo

**PR-005 — Audit checkpoint, verification and export**

- Daily checkpoint anchoring the chain head, a verification routine that walks back only to the last checkpoint, and a trail export for an entity or a time range.
- **Dependencies**: PR-004
- **Complexity**: S (1-2 days)
- **Requirements**: CON-006, FR-041, FR-042
- **Spec sections**: spec:§9, spec:§9,§11
- **Status**: todo

**PR-006 — Identity: users, roles, sessions and OIDC**

- The seven-role model from spec 11, session handling, and OIDC login. LabKey CE has no OIDC provider, so OSM supplies its own.
- **Dependencies**: PR-003
- **Complexity**: M (3-5 days)
- **Requirements**: FR-013, FR-047
- **Spec sections**: spec:§11, spec:§2
- **Status**: todo

**PR-007 — API keys and service accounts**

- Machine credentials with scoped privileges, for the bridge, batch workers and external assistants.
- **Dependencies**: PR-006
- **Complexity**: S (1-2 days)
- **Status**: todo

**PR-008 — FastAPI application skeleton, OpenAPI and RLS plumbing**

- The HTTP surface: routing, a consistent error model, request validation at the boundary, generated OpenAPI, and the per-request PostgreSQL session variables that RLS policies read.
- **Dependencies**: PR-006
- **Complexity**: M (3-5 days)
- **Requirements**: FR-010, FR-043
- **Spec sections**: spec:§10, spec:§2
- **Status**: todo

### Phase I1: Registry (PR-009–PR-015)

**Acceptance gate**: Sample types, sources, samples. Done at aliquot.

**PR-009 — Projects and sample type designer**

- Project entities with retention, and sample types carrying a naming pattern, custom field definitions and permitted statuses (spec 3, spec 4).
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: FR-014, FR-023
- **Spec sections**: spec:§3, spec:§4
- **Status**: todo

**PR-010 — Name expression engine**

- The pattern language for sample and aliquot identifiers, modelled on the tokens LabKey CE supports so that published names round-trip.
- **Dependencies**: PR-009
- **Complexity**: M (3-5 days)
- **Status**: todo

**PR-011 — Sources and sample registration**

- Source entities with a human id and metadata, and the P-INTAKE pipeline: type, id, source, slot and label (spec 17.1).
- **Dependencies**: PR-010
- **Complexity**: M (3-5 days)
- **Requirements**: FR-001, FR-056, PRO-001, PRO-002
- **Spec sections**: spec:§1, spec:§17, spec:§4
- **Status**: todo

**PR-012 — Sample status lifecycle state machine**

- The eight statuses from spec 3 and the transitions between them, enforced server-side. Neither LabKey CE nor the commercial product enforces status rules.
- **Dependencies**: PR-011
- **Complexity**: S (1-2 days)
- **Requirements**: FR-022
- **Spec sections**: spec:§3
- **Status**: todo

**PR-013 — Aliquots, derivation and lineage**

- P-ALIQUOT and P-DERIVE (spec 17.1): amount splitting, child creation, and the lineage graph. This is the I1 acceptance gate.
- **Dependencies**: PR-012
- **Complexity**: M (3-5 days)
- **Requirements**: FR-015, FR-025, FR-057
- **Spec sections**: spec:§17.1, spec:§3, spec:§4
- **Status**: todo

**PR-014 — CSV bulk intake**

- Bulk sample registration from a delimited file, with strict server-side validation and an all-or-nothing outcome.
- **Dependencies**: PR-011
- **Complexity**: M (3-5 days)
- **Requirements**: FR-024
- **Spec sections**: spec:§4
- **Status**: todo

**PR-015 — Sample timeline**

- The chronological view of everything that happened to a sample (spec 4), assembled from the audit trail.
- **Dependencies**: PR-013
- **Complexity**: S (1-2 days)
- **Requirements**: FR-026
- **Spec sections**: spec:§4
- **Status**: todo

### Phase I2: Freezer map (PR-016–PR-020)

**Acceptance gate**: Storage hierarchy and slot operations. Done per spec §5.

**PR-016 — Storage hierarchy model**

- The five levels of spec 5: site/building/room, device, rack/drawer, box/plate and slot, with geometry and capacity.
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: FR-016, FR-028
- **Spec sections**: spec:§3, spec:§5
- **Status**: todo

**PR-017 — Slot assignment, check-in, check-out and move**

- Implements ADR-0004: the exclusion constraint and the atomic P-CHECKIN, P-CHECKOUT and move operations. This is the I2 acceptance gate.
- **Dependencies**: PR-016
- **Complexity**: L (5-10 days)
- **Requirements**: FR-003, FR-029, FR-032, FR-058
- **Spec sections**: spec:§1,§5, spec:§17.1, spec:§5
- **Status**: todo

**PR-018 — Atomic box move and TTL reservations**

- P-BOXMOVE and the time-limited reservation from spec 5, both capabilities the commercial product does not offer.
- **Dependencies**: PR-017
- **Complexity**: M (3-5 days)
- **Requirements**: FR-030, FR-031
- **Spec sections**: spec:§5
- **Status**: todo

**PR-019 — Barcodes and label generation**

- Barcode allocation for samples and storage units, and label rendering including direct ZPL, which the commercial product does not support.
- **Dependencies**: PR-011
- **Complexity**: M (3-5 days)
- **Requirements**: FR-050
- **Spec sections**: spec:§15
- **Status**: todo

**PR-020 — Freezer map user interface**

- The visual map from spec 12, meeting the NFR-001 rendering target.
- **Dependencies**: PR-017
- **Complexity**: L (5-10 days)
- **Requirements**: FR-048, NFR-001, NFR-007
- **Spec sections**: spec:§12, spec:§14, spec:§5
- **Status**: todo

### Phase I3: Workflow (PR-021–PR-023)

**Acceptance gate**: Templates, jobs, tasks. Done at the queue.

**PR-021 — Job templates**

- Reusable SOP skeletons defined without samples (spec 6), with ordered tasks and per-task actions.
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: FR-033
- **Spec sections**: spec:§6
- **Status**: todo

**PR-022 — Jobs, tasks and optimistic locking**

- P-JOB-START and P-JOB-TASK (spec 17.2): instantiate a template against samples or a picklist, and complete tasks safely under concurrency.
- **Dependencies**: PR-021
- **Complexity**: M (3-5 days)
- **Requirements**: FR-004, FR-017, FR-036, FR-059
- **Spec sections**: spec:§1,§6, spec:§17.2, spec:§3, spec:§6
- **Status**: todo

**PR-023 — Queue views, escalation and notification**

- The three queue views from spec 6, T-1 and T+1 due-date escalation, and the notify service.
- **Dependencies**: PR-022
- **Complexity**: M (3-5 days)
- **Requirements**: FR-034, FR-035
- **Spec sections**: spec:§6
- **Status**: todo

### Phase I4: ELN (PR-024–PR-026)

**Acceptance gate**: Notebooks, review, signature. Done at signature.

**PR-024 — Notebooks and the ELN state machine**

- P-ELN-DRAFT (spec 17.2) and the draft to review to approved to signed to locked machine from spec 7.
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: FR-005, FR-018, FR-037
- **Spec sections**: spec:§1,§7, spec:§3, spec:§7
- **Status**: todo

**PR-025 — ELN review workflow**

- P-ELN-REVIEW (spec 17.2): submission to a reviewer queue, approval, change requests and recall.
- **Dependencies**: PR-024
- **Complexity**: S (1-2 days)
- **Requirements**: FR-060
- **Spec sections**: spec:§17.2
- **Status**: todo

**PR-026 — ELN signature, locking and PDF**

- P-ELN-SIGN (spec 17.2): re-authentication, a JSON content hash bound to the signer, immutability and PDF export. This is the I4 acceptance gate.
- **Dependencies**: PR-025
- **Complexity**: L (5-10 days)
- **Requirements**: CON-004, FR-038, PRO-006
- **Spec sections**: spec:§18.2, spec:§7
- **Status**: todo

### Phase I5: Search (PR-027–PR-029)

**Acceptance gate**: Finder, picklists, row-level security. Done with RLS.

**PR-027 — Faceted finder**

- The finder from spec 8: facets over type, lineage, storage and assay thresholds, meeting NFR-002.
- **Dependencies**: PR-013
- **Complexity**: L (5-10 days)
- **Requirements**: FR-006, FR-039, NFR-002
- **Spec sections**: spec:§1,§8, spec:§8
- **Status**: todo

**PR-028 — Picklists**

- Named working sets of samples that can start a job (spec 4, P-PICKLIST).
- **Dependencies**: PR-027
- **Complexity**: S (1-2 days)
- **Requirements**: FR-027
- **Spec sections**: spec:§4,§17.2
- **Status**: todo

**PR-029 — Row-level security enforcement**

- PostgreSQL RLS policies on every domain table, the I5 acceptance gate. Neither LabKey CE nor the commercial product has this.
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: FR-012
- **Spec sections**: spec:§2
- **Status**: todo

### Phase I6: MCP and LabKey bridge (PR-030–PR-035)

**Acceptance gate**: Publishing and agent access. Done when the UI runs through MCP semantics.

**PR-030 — Publish outbox**

- Implements ADR-0005: the transactional queue that decouples OSM writes from LabKey publishing.
- **Dependencies**: PR-013
- **Complexity**: M (3-5 days)
- **Requirements**: FR-021, FR-055, PRO-003
- **Spec sections**: spec:§16.2, spec:§3,§16.2
- **Status**: todo

**PR-031 — LabKey bridge: sample publishing (P-LK-SAMPLE)**

- The first publish pipeline: create the container and sample type domain in LabKey CE, then import samples idempotently.
- **Dependencies**: PR-030,PR-001
- **Complexity**: L (5-10 days)
- **Requirements**: CON-008, FR-009, FR-051, FR-052, FR-053, FR-054
- **Spec sections**: spec:§1,§16, spec:§16, spec:§16.1, spec:§16.2
- **Status**: todo

**PR-032 — LabKey bridge: assays, lists, studies and portals**

- P-LK-ASSAY, P-LK-LIST and P-LK-STUDY, plus folder.xml portal delivery instead of addWebPart.
- **Dependencies**: PR-031
- **Complexity**: M (3-5 days)
- **Requirements**: CON-009, FR-019, FR-061, PRO-004
- **Spec sections**: spec:§16, spec:§17.3, spec:§3
- **Status**: todo

**PR-033 — MCP server: read tools**

- Implements ADR-0006: the MCP transport as an HTTP client of the REST API, starting with read-only tools.
- **Dependencies**: PR-008
- **Complexity**: M (3-5 days)
- **Requirements**: CON-005, CON-012, FR-008, FR-044, FR-064, FR-065
- **Spec sections**: spec:§1,§10, spec:§10, spec:§18, spec:§18.3, spec:§8,§10
- **Status**: todo

**PR-034 — MCP server: guarded write tools**

- Write tools with the confirm and scope requirements of spec 10, and the absolute prohibitions of spec 18.2.
- **Dependencies**: PR-033
- **Complexity**: M (3-5 days)
- **Requirements**: CON-010, FR-045, FR-046, PRO-005, PRO-007
- **Spec sections**: spec:§10, spec:§18.2, spec:§18.3
- **Status**: todo

**PR-035 — Assistant channels and RAG guardrails**

- The three channels of spec 18.3 and the use cases of spec 18.1, with a corpus restricted to SOPs, templates and schemas.
- **Dependencies**: PR-034
- **Complexity**: M (3-5 days)
- **Requirements**: CON-011, FR-066, FR-067, PRO-008, PRO-009
- **Spec sections**: spec:§18.1, spec:§18.2, spec:§18.3
- **Status**: todo

### Phase I7: Operations (PR-036–PR-038)

**Acceptance gate**: Pipelines, benchmarks, runbook. Done at the runbook.

**PR-036 — Operations pipelines**

- P-REINDEX, P-AUDIT-CKPT, P-RETENTION, P-KEY-ROTATE and P-RESTORE-DRILL from spec 17.4.
- **Dependencies**: PR-029
- **Complexity**: M (3-5 days)
- **Requirements**: FR-049, FR-062, FR-063
- **Spec sections**: spec:§15, spec:§17.3, spec:§17.4
- **Status**: todo

**PR-037 — Performance benchmarks against the non-functional targets**

- Benchmarks that can fail, covering the spec 14 and spec 8 targets rather than asserting them.
- **Dependencies**: PR-027
- **Complexity**: M (3-5 days)
- **Requirements**: NFR-003, NFR-004, NFR-005
- **Spec sections**: spec:§14
- **Status**: todo

**PR-038 — Deployment, backup and runbook**

- The I7 acceptance gate: a runbook that a second person could follow.
- **Dependencies**: PR-036
- **Complexity**: M (3-5 days)
- **Requirements**: NFR-006
- **Spec sections**: spec:§14
- **Status**: todo

## Implementation Guidelines

### Prerequisites

- Read `memory.md`, then `AGENTS.md`.
- `tools/memory.py check` passes before you start and before you finish.
- Scaffolding tasks (PR-001 through PR-008) complete before any feature work.

### Quality gates

- [ ] Lint and type checks pass with zero errors
- [ ] All tests pass and coverage stays above the configured threshold
- [ ] Every acceptance criterion in the task is met, including the denials
- [ ] No secret, credential or token appears anywhere in the diff
- [ ] Every new claim about LabKey behaviour is recorded as a verification
- [ ] Every new domain table has a row-level security policy
- [ ] `tools/memory.py check` passes and the dump is committed
- [ ] A `JOURNAL.md` entry is appended

### Verification requirement

This project's characteristic failure is a plausible but wrong belief about
LabKey Community Edition. Five capabilities look present and enforce nothing
(see `docs/gap-analysis.md`). Any statement about LabKey behaviour must be
backed by source under `/root/scicore` or by a real HTTP call, and recorded
with `tools/memory.py add verification`.

## Requirement to Task Mapping

| Requirement | Kind | Iteration | Title | Task |
| --- | --- | --- | --- | --- |
| CON-001 | constraint | — | Licensing: Apache-2.0 for code, CC-BY-4.0 for content | — |
| CON-002 | constraint | — | OSM must not be a LabKey UI clone | — |
| CON-003 | constraint | — | LabKey is strictly downstream | — |
| CON-004 | constraint | — | Signed notebooks are immutable | PR-026 |
| CON-005 | constraint | — | The UI is a client of the same API the MCP server exposes | PR-033 |
| CON-006 | constraint | — | Auditor role is read-only | PR-005 |
| CON-007 | constraint | — | DPIA required before any USB identifier is processed | — |
| CON-008 | constraint | — | LabKey server audit supplements but never replaces the OSM trail | PR-031 |
| CON-009 | constraint | — | Study publish requires Subject and Timepoint, otherwise reject | PR-032 |
| CON-010 | constraint | — | At most one unsafe write chain per turn | PR-034 |
| CON-011 | constraint | — | RAG corpus limited to SOPs, templates and schemas | PR-035 |
| CON-012 | constraint | — | Prompt injection in an SOP PDF must not unlock extra tools | PR-033 |
| CON-013 | constraint | — | Iteration acceptance gates | — |
| CON-014 | constraint | — | Freezer map, job queue, ELN and finder have independent acceptance | — |
| FR-001 | functional | I1 | Register, store, process, document and search samples | PR-011 |
| FR-002 | functional | I0 | Chain of custody for every sample | PR-004 |
| FR-003 | functional | I2 | Freezer map with 1:1 physical correspondence | PR-017 |
| FR-004 | functional | I3 | SOP-driven jobs with a work queue | PR-022 |
| FR-005 | functional | I4 | Electronic lab notebook with signature | PR-024 |
| FR-006 | functional | I5 | Faceted search across samples, lineage, storage and assays | PR-027 |
| FR-007 | functional | I0 | Hash-chained audit trail | PR-004 |
| FR-008 | functional | I6 | REST API plus MCP server | PR-033 |
| FR-009 | functional | I6 | Publish to LabKey CE without addWebPart | PR-031 |
| FR-010 | functional | I0 | Service decomposition into eleven domain services | PR-008 |
| FR-011 | functional | I0 | Every write is audited in the same transaction | PR-004 |
| FR-012 | functional | I5 | PostgreSQL with row-level security | PR-029 |
| FR-013 | functional | I0 | OIDC authentication, roles and API keys | PR-006 |
| FR-014 | functional | I1 | Core entities: Project, SampleType, Source, Sample | PR-009 |
| FR-015 | functional | I1 | AliquotLink models aliquot and derived relations | PR-013 |
| FR-016 | functional | I2 | StorageNode and Slot entities with geometry and occupancy | PR-016 |
| FR-017 | functional | I3 | Job and Task entities | PR-022 |
| FR-018 | functional | I4 | Notebook entity with status and content hash | PR-024 |
| FR-019 | functional | I1 | AssayRun entity linking a design to samples | PR-032 |
| FR-020 | functional | I0 | AuditEvent stores before/after state and previous hash | PR-004 |
| FR-021 | functional | I6 | PublishOutbox entity for LabKey delivery | PR-030 |
| FR-022 | functional | I1 | Eight sample lifecycle statuses | PR-012 |
| FR-023 | functional | I1 | Sample type designer | PR-009 |
| FR-024 | functional | I1 | CSV bulk intake of samples | PR-014 |
| FR-025 | functional | I1 | Create aliquots and derivatives | PR-013 |
| FR-026 | functional | I1 | Sample timeline view | PR-015 |
| FR-027 | functional | I5 | Picklists | PR-028 |
| FR-028 | functional | I2 | Five-level storage hierarchy | PR-016 |
| FR-029 | functional | I2 | Atomic check-in, check-out and move | PR-017 |
| FR-030 | functional | I2 | Box move as an atomic batch | PR-018 |
| FR-031 | functional | I2 | TTL-based slot reservation | PR-018 |
| FR-032 | functional | I2 | Slot conflict returns HTTP 409 | PR-017 |
| FR-033 | functional | I3 | Job templates are defined without samples | PR-021 |
| FR-034 | functional | I3 | Queue views: my tasks, active jobs, board | PR-023 |
| FR-035 | functional | I3 | Due-date escalation at T-1 and T+1 | PR-023 |
| FR-036 | functional | I3 | Optimistic locking on task completion | PR-022 |
| FR-037 | functional | I4 | ELN state machine draft->review->approved->signed->locked | PR-024 |
| FR-038 | functional | I4 | Signature requires re-authentication and a JSON hash | PR-026 |
| FR-039 | functional | I5 | Search facets over type, lineage, storage and assay thresholds | PR-027 |
| FR-040 | functional | I0 | Append-only audit with SHA-256 hash chain | PR-004 |
| FR-041 | functional | I0 | Daily audit checkpoint | PR-005 |
| FR-042 | functional | I0 | Audit trail export | PR-005 |
| FR-043 | functional | I0 | Core REST endpoints | PR-008 |
| FR-044 | functional | I6 | MCP tool namespaces mirror REST semantics | PR-033 |
| FR-045 | functional | I6 | Destructive actions require confirm=true and osm.admin.write | PR-034 |
| FR-046 | functional | I6 | Audit records actor_type=mcp for agent-initiated writes | PR-034 |
| FR-047 | functional | I0 | Seven-role authorisation model | PR-006 |
| FR-048 | functional | I1 | Own UX with eight top-level areas | PR-020 |
| FR-049 | functional | I7 | Temperature logger integration (open) | PR-036 |
| FR-050 | functional | I2 | ZPL label printer support (open) | PR-019 |
| FR-051 | functional | I6 | Publish to LabKey using CSRF, createContainer, Domain, query-import, wiki-save, WebDAV | PR-031 |
| FR-052 | functional | I6 | Map OSM objects onto LabKey modules | PR-031 |
| FR-053 | functional | I6 | Publish mapping rules | PR-031 |
| FR-054 | functional | I6 | osm_id carried into LabKey for idempotent publishing | PR-031 |
| FR-055 | functional | I6 | Outbox worker consumes sample.committed, assay.uploaded, notebook.signed | PR-030 |
| FR-056 | functional | I1 | Uniform pipeline shape | PR-011 |
| FR-057 | functional | I1 | Inventory pipelines P-INTAKE, P-ALIQUOT, P-DERIVE | PR-013 |
| FR-058 | functional | I2 | Storage pipelines P-CHECKIN, P-CHECKOUT, P-BOXMOVE, P-DISCARD, P-SHIP | PR-017 |
| FR-059 | functional | I3 | Work pipelines P-JOB-START, P-JOB-TASK, P-JOB-BLOCK | PR-022 |
| FR-060 | functional | I4 | Documentation pipelines P-ASSAY-UP, P-ELN-DRAFT, P-ELN-REVIEW, P-ELN-SIGN, P-PICKLIST | PR-025 |
| FR-061 | functional | I6 | LabKey publish pipelines P-LK-SAMPLE, P-LK-ASSAY, P-LK-LIST, P-LK-STUDY | PR-032 |
| FR-062 | functional | I7 | External data pipelines P-GEO-META, P-UNIPROT, P-BAG-SYNC, P-SPHN-TOKEN | PR-036 |
| FR-063 | functional | I7 | Operations pipelines | PR-036 |
| FR-064 | functional | I6 | LLMs act only through MCP tools | PR-033 |
| FR-065 | functional | I6 | Every LLM call emits an llm.invoke audit event | PR-033 |
| FR-066 | functional | I6 | Assistant use cases | PR-035 |
| FR-067 | functional | I6 | Three assistant channels | PR-035 |
| NFR-001 | nonfunctional | I2 | Freezer map renders 1000 boxes of 81 slots smoothly | PR-020 |
| NFR-002 | nonfunctional | I5 | Search P95 below 300 ms at one million samples | PR-027 |
| NFR-003 | nonfunctional | I0 | API P95 latency below 200 ms | PR-037 |
| NFR-004 | nonfunctional | I0 | 100 concurrent users | PR-037 |
| NFR-005 | nonfunctional | I0 | One million samples | PR-037 |
| NFR-006 | nonfunctional | I7 | Point-in-time recovery for seven days | PR-038 |
| NFR-007 | nonfunctional | I1 | Target WCAG 2.2 AA accessibility | PR-020 |
| PRO-001 | prohibition | — | No SPHN/USB patient payload in OSM | PR-011 |
| PRO-002 | prohibition | — | Study PID only as an opaque token | PR-011 |
| PRO-003 | prohibition | — | Strip PHI on publish | PR-030 |
| PRO-004 | prohibition | — | Do not use addWebPart against LabKey | PR-032 |
| PRO-005 | prohibition | — | LLMs may never discard, ship or lock without a human | PR-034 |
| PRO-006 | prohibition | — | LLMs may never sign an ELN entry | PR-026 |
| PRO-007 | prohibition | — | LLMs may never change permissions | PR-034 |
| PRO-008 | prohibition | — | No PHI in prompts | PR-035 |
| PRO-009 | prohibition | — | No SQL or shell access outside the declared tools | PR-035 |

## Task Estimation

- **S** (1-2 days): 7 tasks
- **M** (3-5 days): 26 tasks
- **L** (5-10 days): 5 tasks

**Total tasks**: 38

