-- OSM project memory database - deterministic dump.
-- Source of truth in git. Regenerate the binary db with: tools/memory.py rebuild
-- Do not hand-edit; use tools/memory.py.
BEGIN TRANSACTION;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Requirements extracted from the specification document.
CREATE TABLE IF NOT EXISTS requirements (
    id          TEXT PRIMARY KEY,            -- FR-001 / NFR-001 / CON-001
    kind        TEXT NOT NULL,               -- functional|nonfunctional|constraint|prohibition
    title       TEXT NOT NULL,
    body        TEXT NOT NULL DEFAULT '',
    source      TEXT NOT NULL,               -- e.g. "spec:§5" (traceability to the .docx)
    priority    TEXT NOT NULL DEFAULT 'must',-- must|should|could|wont
    iteration   TEXT NOT NULL DEFAULT '',    -- I0..I7 per spec §13
    status      TEXT NOT NULL DEFAULT 'open',-- open|planned|in-progress|done|deferred
    created_at  TEXT NOT NULL,
    CHECK (kind IN ('functional','nonfunctional','constraint','prohibition')),
    CHECK (priority IN ('must','should','could','wont')),
    CHECK (status IN ('open','planned','in-progress','done','deferred'))
);

-- Research findings, each pinned to verifiable evidence.
CREATE TABLE IF NOT EXISTS research (
    id            TEXT PRIMARY KEY,          -- RF-001
    topic         TEXT NOT NULL,
    finding       TEXT NOT NULL,
    evidence_kind TEXT NOT NULL,             -- source|http|doc|web|reasoning
    evidence_ref  TEXT NOT NULL DEFAULT '',  -- absolute file path, URL, or API action
    confidence    TEXT NOT NULL DEFAULT 'high', -- high|medium|low
    created_at    TEXT NOT NULL,
    CHECK (evidence_kind IN ('source','http','doc','web','reasoning')),
    CHECK (confidence IN ('high','medium','low'))
);

-- Architecture Decision Records (mirrored to specs/adr/ as markdown).
CREATE TABLE IF NOT EXISTS decisions (
    id           TEXT PRIMARY KEY,           -- ADR-001
    title        TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'proposed', -- proposed|accepted|superseded|rejected
    context      TEXT NOT NULL DEFAULT '',
    decision     TEXT NOT NULL DEFAULT '',
    consequences TEXT NOT NULL DEFAULT '',
    alternatives TEXT NOT NULL DEFAULT '',
    supersedes   TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL,
    CHECK (status IN ('proposed','accepted','superseded','rejected'))
);

-- Feature / gap inventory: commercial LabKey Sample Manager vs LabKey CE vs OSM.
CREATE TABLE IF NOT EXISTS features (
    id         TEXT PRIMARY KEY,             -- FEAT-001
    area       TEXT NOT NULL,                -- registry|storage|workflow|eln|search|audit|api|labkey|llm|ops|ui|security
    name       TEXT NOT NULL,
    detail     TEXT NOT NULL DEFAULT '',
    commercial TEXT NOT NULL DEFAULT 'unknown', -- yes|no|partial|unknown  (does LabKey Sample Manager have it)
    ce_support TEXT NOT NULL DEFAULT 'unknown', -- native|partial|custom|absent|unknown (LabKey CE)
    gap        TEXT NOT NULL DEFAULT 'unknown', -- none|low|medium|high  (effort for OSM)
    evidence   TEXT NOT NULL DEFAULT '',
    notes      TEXT NOT NULL DEFAULT '',
    CHECK (commercial IN ('yes','no','partial','unknown')),
    CHECK (ce_support IN ('native','partial','custom','absent','unknown')),
    CHECK (gap IN ('none','low','medium','high','unknown'))
);

-- Ordered, reviewable PR backlog.
CREATE TABLE IF NOT EXISTS backlog (
    id         TEXT PRIMARY KEY,             -- PR-001
    seq        INTEGER NOT NULL,             -- review/merge order
    title      TEXT NOT NULL,
    summary    TEXT NOT NULL DEFAULT '',
    acceptance TEXT NOT NULL DEFAULT '',     -- newline-separated acceptance criteria
    depends_on TEXT NOT NULL DEFAULT '',     -- comma-separated PR ids
    iteration  TEXT NOT NULL DEFAULT '',     -- I0..I7
    size       TEXT NOT NULL DEFAULT 'M',    -- XS|S|M|L
    branch     TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'todo', -- todo|in-progress|review|done|blocked
    created_at TEXT NOT NULL,
    CHECK (size IN ('XS','S','M','L')),
    CHECK (status IN ('todo','in-progress','review','done','blocked'))
);

CREATE TABLE IF NOT EXISTS tasks (
    id         TEXT PRIMARY KEY,             -- T-001
    pr_id      TEXT NOT NULL REFERENCES backlog(id) ON DELETE CASCADE,
    seq        INTEGER NOT NULL DEFAULT 0,
    title      TEXT NOT NULL,
    detail     TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'todo',
    created_at TEXT NOT NULL,
    CHECK (status IN ('todo','in-progress','done','blocked'))
);

-- How a claim about the environment was actually verified (never assume).
CREATE TABLE IF NOT EXISTS verifications (
    id          TEXT PRIMARY KEY,            -- V-001
    claim       TEXT NOT NULL,
    method      TEXT NOT NULL,               -- http|source|shell|doc
    command     TEXT NOT NULL DEFAULT '',
    result      TEXT NOT NULL,               -- pass|fail|partial
    detail      TEXT NOT NULL DEFAULT '',
    verified_at TEXT NOT NULL,
    CHECK (method IN ('http','source','shell','doc')),
    CHECK (result IN ('pass','fail','partial'))
);

-- Traceability graph: requirement -> artifact (feature, backlog item, adr, file...).
CREATE TABLE IF NOT EXISTS traceability (
    req_id        TEXT NOT NULL REFERENCES requirements(id) ON DELETE CASCADE,
    artifact_kind TEXT NOT NULL,             -- feature|backlog|decision|verification|file|spec
    artifact_ref  TEXT NOT NULL,
    PRIMARY KEY (req_id, artifact_kind, artifact_ref)
);

CREATE INDEX IF NOT EXISTS idx_backlog_seq      ON backlog(seq);
CREATE INDEX IF NOT EXISTS idx_tasks_pr         ON tasks(pr_id, seq);
CREATE INDEX IF NOT EXISTS idx_features_area    ON features(area);
CREATE INDEX IF NOT EXISTS idx_req_iteration    ON requirements(iteration);
CREATE INDEX IF NOT EXISTS idx_trace_artifact   ON traceability(artifact_kind, artifact_ref);
-- meta: 3 rows
INSERT INTO meta(key,value) VALUES('created_at','2026-08-26T08:29:24Z');
INSERT INTO meta(key,value) VALUES('project','open-sample-manager');
INSERT INTO meta(key,value) VALUES('schema_version','1');
-- requirements: 97 rows
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-001','constraint','Licensing: Apache-2.0 for code, CC-BY-4.0 for content','Apache-2.0 / CC-BY-4.0.','spec:§1','must','','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-002','constraint','OSM must not be a LabKey UI clone','Kein LabKey-UI-Klon. OSM has its own UX (§12) and is independent of LabKey products.','spec:§1','must','','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-003','constraint','LabKey is strictly downstream','LabKey ist Downstream. OSM is the system of record; LabKey CE is a publish target only.','spec:§1,§16','must','','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-004','constraint','Signed notebooks are immutable','Signed unveraenderlich. No update path may mutate a signed notebook.','spec:§7','must','','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-005','constraint','The UI is a client of the same API the MCP server exposes','MCP a UI: no privileged back door for the UI; both go through the same API and authorisation.','spec:§8,§10','must','','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-006','constraint','Auditor role is read-only','Auditor nur lesen: the auditor can read the trail and nothing else.','spec:§9,§11','must','','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-007','constraint','DPIA required before any USB identifier is processed','DPIA vor USB-Identifikatoren.','spec:§15','must','','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-008','constraint','LabKey server audit supplements but never replaces the OSM trail','audit (Server) zusaetzlicher Trail - nicht OSM ersetzen.','spec:§16.1','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-009','constraint','Study publish requires Subject and Timepoint, otherwise reject','P-LK-STUDY: Subject+Visit, sonst reject.','spec:§17.3','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-010','constraint','At most one unsafe write chain per turn','Maximal eine unsichere Schreibkette pro Turn.','spec:§18.3','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-011','constraint','RAG corpus limited to SOPs, templates and schemas','RAG nur auf SOPs, Templates, Schemata; nicht auf PHI-ELN oder USB-Dateien.','spec:§18.3','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-012','constraint','Prompt injection in an SOP PDF must not unlock extra tools','Injection in SOP-PDF darf keine Extra-Tools freischalten. The tool allowlist is bound to the session, never to document content.','spec:§18.3','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-013','constraint','Iteration acceptance gates','I0 Auth/Audit/OpenAPI done when the hash chain verifies; I1 Registry done at aliquot; I2 Freezer map done per §5; I3 Workflow done at queue; I4 ELN done at signature; I5 Search done with RLS; I6 MCP+LabKey bridge done when the UI runs through MCP semantics; I7 Operations done at the runbook.','spec:§13','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('CON-014','constraint','Freezer map, job queue, ELN and finder have independent acceptance','Freezer-Map, Job-Queue, ELN und Finder haben eigene Abnahmen.','spec:§19','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-001','functional','Register, store, process, document and search samples','OSM registriert, lagert, bearbeitet, dokumentiert und sucht Proben. It is the System of Record for the sample lifecycle.','spec:§1','must','I1','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-002','functional','Chain of custody for every sample','Every custody transfer (intake, move, ship, discard) is recorded and attributable to an actor.','spec:§1','must','I0','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-003','functional','Freezer map with 1:1 physical correspondence','The storage model mirrors the physical freezer layout exactly (Freezer-Map 1:1); one slot holds at most one sample.','spec:§1,§5','must','I2','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-004','functional','SOP-driven jobs with a work queue','SOP-Jobs mit Queue: templates instantiate jobs whose tasks appear in per-user and per-project queues.','spec:§1,§6','must','I3','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-005','functional','Electronic lab notebook with signature','ELN mit Signatur: notebooks progress draft->review->approved->signed->locked.','spec:§1,§7','must','I4','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-006','functional','Faceted search across samples, lineage, storage and assays','Facettierte Suche (Finder).','spec:§1,§8','must','I5','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-007','functional','Hash-chained audit trail','Hash-Audit: append-only audit with SHA-256 chaining.','spec:§1,§9','must','I0','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-008','functional','REST API plus MCP server','REST plus MCP. MCP tools mirror REST semantics exactly.','spec:§1,§10','must','I6','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-009','functional','Publish to LabKey CE without addWebPart','LabKey-Publish ohne addWebPart. Portals are delivered as folder.xml zip archives instead.','spec:§1,§16','must','I6','open','2026-08-26T08:31:35Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-010','functional','Service decomposition into eleven domain services','identity, registry, storage, workflow, eln, search, audit, file, labkey-bridge, mcp-server, notify.','spec:§2','must','I0','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-011','functional','Every write is audited in the same transaction','Jede Schreiboperation auditiert in derselben Transaktion. Audit write and domain write share one DB transaction; no post-hoc auditing.','spec:§2','must','I0','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-012','functional','PostgreSQL with row-level security','PostgreSQL mit RLS as the persistence layer; object store for files.','spec:§2','must','I5','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-013','functional','OIDC authentication, roles and API keys','identity-service provides OIDC login, role assignment and API keys for machine clients.','spec:§2','must','I0','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-014','functional','Core entities: Project, SampleType, Source, Sample','Project(project_id: name, retention); SampleType(sample_type_id: pattern, fields, statuses); Source(source_id: human_id, meta); Sample(sample_id: status, barcode, slot).','spec:§3','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-015','functional','AliquotLink models aliquot and derived relations','AliquotLink(parent+child) with kind in {aliquot, derived}.','spec:§3','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-016','functional','StorageNode and Slot entities with geometry and occupancy','StorageNode/Slot carry geometry and occupied_by.','spec:§3','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-017','functional','Job and Task entities','Job/Task with owner, due date and status.','spec:§3','must','I3','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-018','functional','Notebook entity with status and content hash','Notebook(notebook_id: status, hash).','spec:§3','must','I4','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-019','functional','AssayRun entity linking a design to samples','AssayRun(run_id: design, samples).','spec:§3','should','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-020','functional','AuditEvent stores before/after state and previous hash','AuditEvent(event_id: before, after, prev_hash).','spec:§3','must','I0','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-021','functional','PublishOutbox entity for LabKey delivery','PublishOutbox(outbox_id: target, state); the transactional outbox pattern decouples OSM writes from LabKey publishing.','spec:§3,§16.2','must','I6','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-022','functional','Eight sample lifecycle statuses','Registered -> Available -> Reserved -> In Process -> Consumed | Locked | Discarded | Shipped.','spec:§3','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-023','functional','Sample type designer','Users define sample types: naming pattern, custom fields, permitted statuses.','spec:§4','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-024','functional','CSV bulk intake of samples','CSV import path for registering samples in bulk.','spec:§4','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-025','functional','Create aliquots and derivatives','Aliquot (same type, split amount) and Derivat (new type, parent link) operations.','spec:§4','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-026','functional','Sample timeline view','Chronological timeline of every event affecting a sample.','spec:§4','must','I1','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-027','functional','Picklists','Named, ordered working sets of samples that can start a job.','spec:§4,§17.2','must','I5','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-028','functional','Five-level storage hierarchy','site/building/room (list) -> device (status, zone) -> rack/drawer (grid, capacity) -> box/plate (rows x cols, A1 origin) -> slot (cell, one sample).','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-029','functional','Atomic check-in, check-out and move','Check-in/out/Move atomar. A move either fully succeeds or leaves both slots unchanged.','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-030','functional','Box move as an atomic batch','Box-Move als Batch: relocating a box moves all contained samples in one transaction.','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-031','functional','TTL-based slot reservation','TTL-Reservierung: a slot can be reserved for a bounded time and is released automatically on expiry.','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-032','functional','Slot conflict returns HTTP 409','Slot-Konflikt 409. Occupancy is enforced by a database constraint, not by application checks alone.','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-033','functional','Job templates are defined without samples','Templates ohne Proben: a template is a reusable SOP skeleton; samples are bound at job start.','spec:§6','must','I3','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-034','functional','Queue views: my tasks, active jobs, board','Queue: meine Tasks, Active Jobs, Board.','spec:§6','must','I3','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-035','functional','Due-date escalation at T-1 and T+1','Eskalation T-1/T+1: notify before and after the due date.','spec:§6','must','I3','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-036','functional','Optimistic locking on task completion','Optimistic Lock auf complete: concurrent completion of the same task is rejected.','spec:§6','must','I3','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-037','functional','ELN state machine draft->review->approved->signed->locked','Only forward transitions; signed entries are immutable.','spec:§7','must','I4','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-038','functional','Signature requires re-authentication and a JSON hash','Signatur mit Re-Auth und JSON-Hash: the canonical JSON of the notebook is hashed and bound to the signer.','spec:§7','must','I4','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-039','functional','Search facets over type, lineage, storage and assay thresholds','Facetten, Lineage, Lager, Assay-Schwellen.','spec:§8','must','I5','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-040','functional','Append-only audit with SHA-256 hash chain','Each event stores prev_hash; tampering breaks the chain.','spec:§9','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-041','functional','Daily audit checkpoint','Tages-Checkpoint anchors the chain so verification does not need a full replay.','spec:§9','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-042','functional','Audit trail export','Trail-Export for an entity or a time range.','spec:§9','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-043','functional','Core REST endpoints','POST /samples (intake), POST /storage/moves, POST /jobs, POST /notebooks/{id}/sign, GET /search.','spec:§10','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-044','functional','MCP tool namespaces mirror REST semantics','osm.samples.*, osm.storage.*, osm.jobs.*, osm.eln.append_ref (draft only), osm.audit.for_entity, osm.labkey.publish_status.','spec:§10','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-045','functional','Destructive actions require confirm=true and osm.admin.write','confirm=true plus osm.admin.write fuer destruktive Aktionen.','spec:§10','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-046','functional','Audit records actor_type=mcp for agent-initiated writes','actor_type=mcp im Audit distinguishes agent actions from human actions.','spec:§10','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-047','functional','Seven-role authorisation model','Reader (read); Technician (create, store, own tasks); Scientist (jobs, ELN draft, assays); Reviewer (sign); Storage/Workflow admin (structure); Project admin (types, members); Auditor (trail only).','spec:§11','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-048','functional','Own UX with eight top-level areas','Dashboard, Samples, Sources, Map, Workflow, ELN, Finder, Admin.','spec:§12','must','I1','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-049','functional','Temperature logger integration (open)','Temperatur-Logger. Unresolved in the spec; treat as a deferred integration.','spec:§15','could','I7','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-050','functional','ZPL label printer support (open)','ZPL-Drucker. Unresolved in the spec.','spec:§15','could','I2','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-051','functional','Publish to LabKey using CSRF, createContainer, Domain, query-import, wiki-save, WebDAV','APIs wie UCI/Biomed. Reuse the established script conventions.','spec:§16','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-052','functional','Map OSM objects onto LabKey modules','Sample/Aliquot/Lineage -> experiment Sample Types; Source -> Data Classes; AssayRun -> assay; catalogs -> list; file pointers -> pipeline/filecontent via WebDAV; SOPs -> wiki; charts -> visualization.','spec:§16.1','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-053','functional','Publish mapping rules','Project -> LabKey project/subfolder; human_id unique plus AutoIncrement key; lineage as lookups; storage_path as a plain string (the map stays in OSM); jobs as a list read-model; ELN PDF to @files/eln/.','spec:§16.2','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-054','functional','osm_id carried into LabKey for idempotent publishing','osm_id fuer Idempotenz: re-publishing the same object must not duplicate rows.','spec:§16.2','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-055','functional','Outbox worker consumes sample.committed, assay.uploaded, notebook.signed','labkey-bridge (I6) arbeitet osm_publish_queue ab. Failures are stored as FAILED including the HTTP response body.','spec:§16.2','must','I6','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-056','functional','Uniform pipeline shape','Trigger -> Validierung -> Aktion -> Audit -> optional Notify/Publish/LLM. Every pipeline follows this shape.','spec:§17','must','I1','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-057','functional','Inventory pipelines P-INTAKE, P-ALIQUOT, P-DERIVE','P-INTAKE (type, id, source, slot, label); P-ALIQUOT (amount, children, lineage); P-DERIVE (type change plus parent).','spec:§17.1','must','I1','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-058','functional','Storage pipelines P-CHECKIN, P-CHECKOUT, P-BOXMOVE, P-DISCARD, P-SHIP','P-CHECKIN (occupy); P-CHECKOUT (free, Reserved); P-BOXMOVE (atomic batch); P-DISCARD (status, free slot); P-SHIP (custody, Shipped).','spec:§17.1','must','I2','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-059','functional','Work pipelines P-JOB-START, P-JOB-TASK, P-JOB-BLOCK','P-JOB-START (template+samples -> tasks, queue, notify); P-JOB-TASK (checklist, next step); P-JOB-BLOCK (escalation).','spec:§17.2','must','I3','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-060','functional','Documentation pipelines P-ASSAY-UP, P-ELN-DRAFT, P-ELN-REVIEW, P-ELN-SIGN, P-PICKLIST','P-ASSAY-UP (parse, match, index); P-ELN-SIGN (re-auth, hash, lock, PDF).','spec:§17.2','must','I4','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-061','functional','LabKey publish pipelines P-LK-SAMPLE, P-LK-ASSAY, P-LK-LIST, P-LK-STUDY','Driven by the outbox.','spec:§17.3','must','I6','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-062','functional','External data pipelines P-GEO-META, P-UNIPROT, P-BAG-SYNC, P-SPHN-TOKEN','P-GEO-META (accession metadata, no FASTQ); P-UNIPROT (accessions -> meta fields); P-BAG-SYNC (cron Wednesday, IDD-CSV); P-SPHN-TOKEN (manual, concept map only).','spec:§17.3','should','I7','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-063','functional','Operations pipelines','P-REINDEX, P-AUDIT-CKPT, P-RETENTION, P-KEY-ROTATE, P-RESTORE-DRILL.','spec:§17.4','must','I7','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-064','functional','LLMs act only through MCP tools','LLMs nutzen nur MCP-Tools. Keine Domain-Aktion ohne Tool.','spec:§18','must','I6','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-065','functional','Every LLM call emits an llm.invoke audit event','llm.invoke records model_id and request_id.','spec:§18','must','I6','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-066','functional','Assistant use cases','CSV intake mapping, SOP->template drafting, natural-language finder, free-slot lookup, queue prioritisation (read-only), ELN drafting, assay mismatch explanation, audit questions, LabKey error triage, GEO/PRIDE metadata.','spec:§18.1','should','I6','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('FR-067','functional','Three assistant channels','UI chat against the local MCP; external assistants via API key on POST /mcp; batch workers on a service account writing into a review queue.','spec:§18.3','must','I6','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-001','nonfunctional','Freezer map renders 1000 boxes of 81 slots smoothly','1000 Boxen a 81 Slots ohne Ruckeln (~81000 slots).','spec:§5','must','I2','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-002','nonfunctional','Search P95 below 300 ms at one million samples','P95 < 300 ms bei 1e6 Proben.','spec:§8','must','I5','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-003','nonfunctional','API P95 latency below 200 ms','API P95 < 200 ms.','spec:§14','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-004','nonfunctional','100 concurrent users','100 parallele Nutzer.','spec:§14','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-005','nonfunctional','One million samples','1e6 Proben.','spec:§14','must','I0','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-006','nonfunctional','Point-in-time recovery for seven days','PITR 7 Tage.','spec:§14','must','I7','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('NFR-007','nonfunctional','Target WCAG 2.2 AA accessibility','WCAG 2.2 AA anstreben.','spec:§14','should','I1','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-001','prohibition','No SPHN/USB patient payload in OSM','Kein SPHN-/USB-Patientenpayload. Only tokenised identifiers may enter OSM.','spec:§1','must','','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-002','prohibition','Study PID only as an opaque token','Study-PID nur als Token. No re-identifiable patient identifier is stored.','spec:§4','must','','open','2026-08-26T08:31:36Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-003','prohibition','Strip PHI on publish','PHI beim Publish streichen.','spec:§16.2','must','','open','2026-08-26T08:31:37Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-004','prohibition','Do not use addWebPart against LabKey','Kein addWebPart. Portals are delivered as folder.xml zip archives.','spec:§16','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-005','prohibition','LLMs may never discard, ship or lock without a human','Discard/Ship/Lock ohne Mensch verboten.','spec:§18.2','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-006','prohibition','LLMs may never sign an ELN entry','ELN-Signatur verboten.','spec:§18.2','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-007','prohibition','LLMs may never change permissions','Rechte aendern verboten.','spec:§18.2','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-008','prohibition','No PHI in prompts','PHI in Prompts verboten.','spec:§18.2','must','','open','2026-08-26T08:31:38Z');
INSERT INTO requirements(id,kind,title,body,source,priority,iteration,status,created_at) VALUES('PRO-009','prohibition','No SQL or shell access outside the declared tools','SQL/Shell ausserhalb der Tools verboten.','spec:§18.2','must','','open','2026-08-26T08:31:38Z');
COMMIT;
