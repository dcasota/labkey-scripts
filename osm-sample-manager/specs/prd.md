# Product Requirements Document (PRD)

## 1. Purpose

Laboratories that need to track a sample from intake to disposal — where it is
in which freezer, what it was split from, who touched it, under which SOP, and
what was written down about it — currently face a binary choice. Either they buy
a commercial LIMS, or they assemble something out of spreadsheets.

LabKey Community Edition looks like a third option and is not. It provides the
sample *data model* — sample types, naming patterns, lineage, aliquot columns,
an audit trail — but essentially none of the sample *management application*.
Freezer mapping, sample status enforcement, check-in and check-out, picklists,
the sample finder, workflow jobs and the electronic lab notebook are all
commercial. LabKey sells them starting at USD 6,540 per year for five users and
reaching USD 59,400 per year.

**Open Sample Manager (OSM) is that missing application layer, built as open
source.** It registers, stores, processes, documents and searches samples; it
carries an auditable chain of custody; and it publishes its results downstream
into LabKey CE so an institution keeps LabKey as its analysis and sharing
surface without paying for the LIMS tier.

**Target users**: research laboratories at Universität Basel (Biomed / Open
LIMS) and comparable institutions — technicians handling samples, scientists
running protocols, reviewers signing records, storage and workflow
administrators, and auditors.

## 2. Scope

### In Scope

- The full sample lifecycle: registration, aliquoting, derivation, storage,
  processing, shipping and disposal, across eight lifecycle statuses.
- A freezer map that corresponds one-to-one with the physical layout, down to
  the individual slot.
- SOP-driven jobs with a work queue, assignment and due-date escalation.
- An electronic lab notebook with review and a binding signature.
- A faceted finder over sample properties, lineage, storage and assay results.
- A tamper-evident audit trail covering every write.
- A REST API and an MCP server, with the user interface as an ordinary client
  of the same API.
- Publishing into LabKey Community Edition as a downstream target.
- Assistant support through MCP tools, with explicit confirmation for writes.

### Out of Scope

- Reimplementing the LabKey user interface. OSM has its own (§12 of the
  specification is explicit: *"Kein LabKey-UI-Klon"*).
- Being a LabKey module. OSM is independent of LabKey products and LabKey is
  strictly downstream. See `specs/adr/0001-osm-is-the-system-of-record.md`.
- Storing patient-identifiable data. Study identifiers enter OSM only as opaque
  tokens; SPHN and USB patient payloads are excluded outright.
- Replacing LabKey's own audit trail. The LabKey trail supplements OSM's and
  never substitutes for it.
- Instrument control, sequencing pipelines, or primary analysis. OSM stores
  pointers to raw data, not the data itself.
- Temperature logger integration and USB identifier processing, both of which
  the specification leaves open (§15); the latter requires a DPIA first.

## 3. Goals & Success Criteria

### Goals

- Give a laboratory an auditable, physically accurate record of where every
  sample is and what has happened to it.
- Make the record trustworthy enough to rely on: signed, hash-chained, and
  attributable.
- Keep LabKey CE valuable by publishing into it rather than competing with it.
- Let an assistant help without letting it act unsupervised.
- Remain free to run and modify: Apache-2.0 for code, CC-BY-4.0 for content.

### Success Criteria

- The audit hash chain verifies end to end, and tampering with any event is
  detected.
- A slot never holds two samples, proven under concurrent load rather than
  asserted.
- API P95 stays below 200 ms with 100 concurrent users; search P95 stays below
  300 ms across one million samples; a freezer map of 1000 boxes of 81 slots
  renders without stutter. Each is a benchmark that fails the build, not an
  aspiration.
- A signed notebook cannot be altered, and an attempt is detectable.
- Re-publishing the same object to LabKey never duplicates a row.
- An assistant cannot perform any operation the same principal could not perform
  over REST, and prohibited operations are not reachable at all.
- Point-in-time recovery to any moment in the last seven days, demonstrated by a
  scheduled restore drill.

## 4. High-Level Requirements

### Core Capabilities

- **[REQ-1] Sample registry with lineage and aliquots**
  Sample types with custom fields and naming patterns; sources; registration
  individually and by bulk import; aliquots that split an amount exactly;
  derivatives that change type while keeping a parent link; pooling; and a
  queryable lineage graph. Amounts are exact decimals, not floats.
  *Memory: FR-001, FR-014, FR-015, FR-019, FR-023 through FR-027, FR-057.*

- **[REQ-2] Eight-status lifecycle, enforced**
  Registered → Available → Reserved → In Process → Consumed | Locked |
  Discarded | Shipped, with only declared transitions permitted. A consumed
  sample cannot be aliquoted; a locked sample rejects every mutation except
  picklist membership. Enforcement is server-side.
  *Memory: FR-022, FR-012.*

- **[REQ-3] Freezer map with one-to-one physical correspondence**
  Five levels — site/building/room, device, rack/drawer, box/plate, slot — where
  a slot holds at most one sample. Check-in, check-out and move are atomic; a
  box move is an atomic batch; slots can be reserved with a time limit; a
  conflict returns a conflict, not a silent overwrite.
  *Memory: FR-003, FR-016, FR-028 through FR-032, NFR-001.*

- **[REQ-4] SOP-driven jobs with a work queue**
  Templates defined without samples; jobs instantiated against samples or a
  picklist; ordered tasks assigned to users or groups; queue views for my tasks,
  active jobs and a board; escalation before and after the due date; and
  optimistic locking so two people cannot both complete the same task.
  *Memory: FR-004, FR-017, FR-033 through FR-036, FR-059.*

- **[REQ-5] Electronic lab notebook with a binding signature**
  Draft → review → approved → signed → locked. Signing requires fresh
  re-authentication and binds a canonical content hash to the signer. A signed
  notebook is immutable, and tampering is detectable. Amendments create a new
  revision without disturbing the signed one.
  *Memory: FR-005, FR-018, FR-037, FR-038, FR-060, CON-004.*

- **[REQ-6] Faceted finder**
  Facets over sample properties, ancestor properties, storage location and assay
  thresholds, with counts, returning results fast enough to browse at a million
  samples. Filter expressions are parsed into a typed structure, never
  concatenated into SQL.
  *Memory: FR-006, FR-039, NFR-002.*

- **[REQ-7] Tamper-evident audit of every write**
  Every write is audited inside the same transaction that performs it, so no
  code path can produce an unaudited change. Events are chained with SHA-256 and
  anchored by a daily checkpoint. The trail is exportable. The auditor role can
  read it and nothing else.
  *Memory: FR-002, FR-007, FR-011, FR-020, FR-040 through FR-042, CON-006.*

- **[REQ-8] Authorisation with row-level security**
  Seven roles — Reader, Technician, Scientist, Reviewer, Storage/Workflow admin,
  Project admin, Auditor — over data protected by row-level security in the
  database, so a defect in application code cannot expose another project's
  samples.
  *Memory: FR-012, FR-013, FR-047.*

- **[REQ-9] REST API and MCP server sharing one authorisation path**
  The user interface, external integrations and assistants are all clients of
  the same API. The MCP server translates tools onto REST calls rather than
  reaching into the domain, so an agent structurally cannot exceed the role it
  authenticates as.
  *Memory: FR-008, FR-010, FR-043, FR-044, FR-064, CON-005.*

- **[REQ-10] Publishing to LabKey Community Edition**
  A transactional outbox delivers committed samples, uploaded assays and signed
  notebooks into LabKey CE. Publishing is idempotent, survives LabKey being
  unavailable, and reports failures with the response body rather than
  discarding them.
  *Memory: FR-009, FR-021, FR-051 through FR-055, FR-061.*

- **[REQ-11] Assistant support that cannot act unsupervised**
  Assistants read and propose freely and write only with explicit confirmation
  and an administrative scope. Every invocation is audited with the model and
  request identity. At most one unsafe write chain per turn.
  *Memory: FR-045, FR-046, FR-065 through FR-067, CON-010.*

- **[REQ-12] Operations that can be trusted**
  Idempotent pipelines for reindexing, audit checkpointing, retention, key
  rotation and restore drills; deterministic deployment; and a runbook a second
  person could follow.
  *Memory: FR-063, NFR-006, FR-049.*

### Capabilities Deliberately Withheld

These are requirements, not omissions. Each is a prohibition the specification
states explicitly, and each is verified by a test that asserts the capability is
absent rather than merely refused.

- **[REQ-13] No patient-identifiable data in OSM**
  Study identifiers enter only as opaque tokens. Personal health information is
  stripped when a publish payload is built, so it never reaches the queue.
  *Memory: PRO-001, PRO-002, PRO-003, CON-007.*

- **[REQ-14] Assistants may never discard, ship, lock, sign, or change
  permissions**
  These operations are not exposed as tools at all. A capability that must never
  be reachable is better absent than refused at call time.
  *Memory: PRO-005, PRO-006, PRO-007.*

- **[REQ-15] No content-derived privilege**
  The assistant tool allowlist is bound to the session at authentication time.
  Text inside an SOP PDF can ask for a tool; nothing is listening. The retrieval
  corpus is restricted at index time to SOPs, templates and schemas.
  *Memory: CON-011, CON-012, PRO-008, PRO-009.*

- **[REQ-16] No `addWebPart` against LabKey**
  Portals are delivered as folder archives.
  *Memory: PRO-004.*

## 5. User Stories

### Registration and lineage

```gherkin
As a technician, I want to register a batch of samples from a spreadsheet,
so that intake does not require typing each one and mistakes are caught
before anything is stored.
```

```gherkin
As a technician, I want to split a sample into aliquots and have the parent's
remaining amount update exactly, so that the recorded volume still matches the
tube after a hundred splits.
```

```gherkin
As a scientist, I want to see everything a sample descends from and everything
descended from it, so that I can trace a result back to its origin.
```

### Storage

```gherkin
As a technician, I want the freezer map to match the physical freezer exactly,
so that a slot the screen shows as empty is empty when I open the door.
```

```gherkin
As a technician, I want to be told immediately when someone else has already
taken the slot I am about to use, so that two samples never end up in one place.
```

```gherkin
As a technician, I want to reserve a slot for the next hour while I fetch the
sample, so that the reservation releases itself if I get pulled away.
```

### Work and documentation

```gherkin
As a scientist, I want to start a job from an SOP template against a picklist
of samples, so that the protocol steps become tasks somebody is accountable for.
```

```gherkin
As a technician, I want my outstanding tasks in one queue with due dates,
so that I know what to do next without asking.
```

```gherkin
As a reviewer, I want to sign a notebook with a fresh authentication and know
that it can never be altered afterwards, so that the record is worth signing.
```

### Oversight

```gherkin
As an auditor, I want to verify that the audit trail has not been altered,
so that I can rely on it without trusting the people who operate the system.
```

```gherkin
As an auditor, I want to read the trail and nothing else, so that my access
cannot itself become a risk.
```

### Integration and assistance

```gherkin
As a data manager, I want committed samples to appear in LabKey automatically,
so that the analysis surface stays current without anyone exporting anything.
```

```gherkin
As a data manager, I want a publish that failed while LabKey was down to be
retried rather than lost, so that the two systems converge on their own.
```

```gherkin
As a scientist, I want to ask in plain language which samples are running low
and where the free space is, so that I can plan without learning a query syntax.
```

```gherkin
As a laboratory head, I want an assistant to be unable to discard or ship
anything, so that convenience never becomes an unreviewed destructive action.
```

## 6. Assumptions & Constraints

### Assumptions

- The specification `OSM_Sample_Manager_Spezifikation.docx` v1.1 is the
  contract. Where the project brief and the specification disagree, the
  specification governs, and the disagreement is recorded as a decision.
- A LabKey Community Edition server is available as a publish target but is not
  required for OSM to function. OSM must remain usable while LabKey is down.
- Deployment is a single institutional server, not a multi-tenant cloud service.
- Samples carry no patient-identifiable data, because §1 forbids it.
- Users authenticate against an institutional OIDC provider.

### Constraints

- **Licensing**: Apache-2.0 for code, CC-BY-4.0 for content.
- **Independence**: OSM does not depend on any LabKey product to operate.
- **Scale**: one million samples, 100 concurrent users, seven-day point-in-time
  recovery.
- **Accessibility**: WCAG 2.2 AA is the target.
- **Delivery**: eight iterations, I0 to I7, each with its own acceptance gate.
  The freezer map, job queue, ELN and finder have independent acceptance.
- **Security**: no credential in the repository; least privilege by default;
  validation on the server; every write auditable.

### Technical Considerations

Deferred deliberately to `specs/adr/`, because a PRD that names technologies
constrains decisions that have not been argued yet. The stack, the audit
mechanism, the storage constraint, the publishing pattern and the assistant
boundary each have their own decision record.

### Open Questions

- Temperature logger integration: which loggers, and does OSM poll or receive?
  (§15, unresolved in the specification.)
- ZPL label printing: which printer models must be supported? (§15.) Note that
  the commercial LabKey product supports no ZPL at all, so there is no prior art
  to follow here.
- USB identifiers require a data protection impact assessment before any design
  work begins (§15). Until that exists, the question stays open.
- Whether the audit hash chain should be partitioned per project if the
  serialisation point proves costly under load. The schema allows it; the
  benchmark in PR-037 decides it.

---

**Document Version:** 1.0
**Last Updated:** 2026-08-26
**Status:** Draft — backlog planned (38 pull requests), implementation beginning at PR-001
