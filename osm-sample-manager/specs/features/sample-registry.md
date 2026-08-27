# Feature Requirement Document (FRD): Sample Registry

**Feature ID**: FRD-001
**Feature Name**: Sample registry with lineage, aliquots and bulk intake
**Related PRD Requirements**: REQ-1, REQ-13
**Memory Requirements**: FR-001, FR-014, FR-015, FR-019, FR-023, FR-024, FR-025, FR-026, FR-027, FR-057, FR-068, FR-069, FR-071, FR-072, FR-076, FR-081, PRO-001, PRO-002, CON-007
**Spec Sections**: §1, §3, §4, §15, §17.1
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

The registry is the part of OSM that makes it the system of record. Every other
feature depends on a sample existing here first: storage moves a registered
sample, a job operates on one, the notebook references one, the finder searches
them and the bridge publishes them. If the registry is wrong, nothing downstream
can be right.

It covers the definition of sample types, the registration of samples one at a
time and in bulk, the derivation relationships between them — aliquot, derivative
and pool — and the chronological timeline of what has happened to each.

### Value Proposition

A laboratory that splits a tube into eight aliquots and later derives DNA from
three of them needs to answer, months later, which original tube a result came
from. Spreadsheets lose that link at the first copy-paste. The registry keeps
lineage as data with referential integrity, so the question is a query rather
than an archaeology exercise.

### Success Criteria

- A sample type can be defined, and samples registered against it, without a
  developer.
- Splitting a parent into aliquots conserves the amount exactly: the sum of the
  children plus the remaining parent equals the original, with no floating-point
  drift (FR-072, ADR-0002 mandates `Decimal`).
- A lineage graph of at least six generations can be retrieved in one call.
- A CSV of 10,000 rows imports, or is rejected with the line number and reason
  for every bad row — never partially, never silently.

---

## 2. Functional Requirements

### 2.1 Sample type designer (FR-023, FR-014)

**Description**: An administrator defines a sample type: its naming pattern, its
custom fields with types and validation, and the subset of the eight lifecycle
statuses it permits. Field definitions additionally declare aliquot inheritance
(FR-068) and whether a parent or source relationship is required (FR-076).

**Inputs**: type name, naming pattern, ordered field definitions (name, data
type, required, default, validation), permitted statuses, required lineage
relations, per-field aliquot inheritance flag.

**Outputs**: a persisted `SampleType`, its generated identifier pattern, and an
audit event `sample_type.created` or `sample_type.updated`.

**Acceptance Criteria**:
- A naming pattern that would generate a duplicate human id is rejected at
  design time, not at first collision.
- Changing a field's type on a type that already has samples is refused; the
  path is add-new-field-and-migrate, not mutate-in-place.
- A type may be **archived** rather than deleted (FR-081): archived types are
  hidden from every picker and blocked for new registration, while existing
  samples remain readable and their history intact.
- The right to change a definition is a separate grant from the right to edit
  the data it governs (FR-080, specified in FRD-008).

**Edge Cases**: a pattern containing a field that is later archived; a required
lineage relation added after samples exist (existing rows are grandfathered and
reported, not retroactively invalidated); two administrators editing the same
type concurrently (optimistic version check, last writer is rejected).

### 2.2 Individual registration (FR-001, FR-057 P-INTAKE)

**Description**: Register one sample: assign the human id from the pattern,
attach it to a source, optionally check it straight into a storage slot, and
optionally print a label.

**Inputs**: sample type, field values, source reference, optional slot, optional
amount and unit.

**Outputs**: a `Sample` in status `Registered`, an audit event, and — when a slot
was given — a storage occupancy record (delegated to FRD-003).

**Acceptance Criteria**:
- The pipeline follows the uniform shape trigger → validation → action → audit →
  optional notify/publish (FR-056).
- Amount and unit are supplied together or omitted together, and a negative
  amount is rejected (FR-072).
- An expiry date may be recorded; an expired sample is flagged wherever it is
  displayed, and a standing report lists samples expiring within a window
  (FR-069).
- Registration is atomic with its audit event (FR-011, ADR-0003).

**Edge Cases**: slot already occupied → the whole registration fails with 409 and
no orphan sample; label printer unavailable → the sample is still registered and
the print is queued, because losing a registration to a printer is unacceptable.

### 2.3 Bulk intake by CSV (FR-024)

**Description**: Register many samples from a file, with a mapping step from
columns to fields.

**Inputs**: an uploaded file, a declared content type, a column-to-field mapping.

**Outputs**: either all rows registered, or none, with a per-row error report.

**Acceptance Criteria**:
- The declared content type is validated rather than trusted, and size and row
  count are bounded (AGENTS.md §3).
- Formula injection is neutralised: a cell beginning `=`, `+`, `-` or `@` cannot
  execute when the file is later opened in a spreadsheet.
- Every rejected row is reported with its line number and the reason.
- The import is all-or-nothing within one transaction.

**Edge Cases**: duplicate human ids inside one file; a file whose declared
encoding is wrong; a row that would violate a required lineage relation.

### 2.4 Aliquots, derivatives and pooling (FR-025, FR-015, FR-057)

**Description**: An aliquot splits a parent's amount and keeps its type. A
derivative changes type and keeps a parent link. Pooling records several parents
for one child. All three are `AliquotLink` rows with `kind` in
`{aliquot, derived}`.

**Inputs**: parent sample(s), child count or explicit amounts, target type for a
derivative.

**Outputs**: child samples, `AliquotLink` rows, a decremented parent amount, and
one audit event per created object.

**Acceptance Criteria**:
- The arithmetic is exact: `sum(children) + parent_remaining == parent_before`
  evaluated as `Decimal`.
- Aliquoting a sample whose status forbids it (Consumed, Discarded, Shipped) is
  refused by the lifecycle rules in FRD-002 — server-side, not in the UI.
- Fields flagged non-inheriting are left empty on the aliquot rather than copied
  (FR-068).
- A cycle in the lineage graph is impossible: a child may never be an ancestor
  of its parent.

**Edge Cases**: requesting more total amount than the parent holds; aliquoting a
parent with no recorded amount (permitted, count-only); pooling parents of
different types (permitted, the child's type is declared explicitly).

### 2.5 Sample timeline (FR-026)

**Description**: A chronological view of every event affecting one sample:
registration, storage moves, status changes, job tasks, notebook references,
publishes.

**Acceptance Criteria**:
- The timeline is assembled from the audit trail (FRD-007), not from a second
  event log that could disagree with it.
- Entries the caller may not read are **omitted entirely** — not shown as a
  redacted placeholder that reveals the object exists (CON-015).

### 2.6 Picklists (FR-027)

**Description**: Named, ordered working sets of samples that can start a job.

**Acceptance Criteria**: a picklist may contain a `Locked` sample — membership is
the one mutation a locked sample permits (REQ-2); deleting a picklist never
deletes its samples.

### 2.7 Identifying fields (FR-071)

**Description**: An administrator nominates a bounded set of fields shown
wherever a sample is referenced, so a reference is legible without opening it.

**Acceptance Criteria**: the set is capped (LabKey caps it at six; OSM adopts the
same bound) and every nominated field is one the caller is permitted to read.

### 2.8 Assay runs (FR-019)

**Description**: An `AssayRun` links a design to the samples it measured.

**Acceptance Criteria**: a run references samples that exist; deleting a run does
not delete samples. *Priority: should. Deferred to I1 alongside the registry.*

---

## 3. Data Requirements

| Entity | Key fields | Notes |
| --- | --- | --- |
| `Project` | `project_id`, name, retention | tenancy boundary for RLS (FRD-008) |
| `SampleType` | `sample_type_id`, pattern, fields, statuses | archivable (FR-081) |
| `Source` | `source_id`, type, metadata | parent entity |
| `Sample` | `sample_id`, `human_id`, type, status, amount, unit, expiry | `human_id` unique per project |
| `AliquotLink` | parent, child, `kind` | `kind ∈ {aliquot, derived}` |
| `AssayRun` | `run_id`, design, samples | FR-019 |

Amounts are `NUMERIC`, never `float` — LabKey stores these as floats and the
drift is real (AGENTS.md §7). Retention is a project property because the
retention pipeline (FRD-012) reads it.

---

## 4. User Interface Requirements

Two of the eight top-level areas (FR-048) belong to this feature: **Samples** and
**Sources**. Required views: type designer, registration form, CSV import wizard
with mapping preview, sample detail with timeline, lineage graph, picklist
manager. Accessibility target WCAG 2.2 AA (NFR-007).

---

## 5. Performance Requirements

- One million samples in the registry (NFR-005).
- API P95 under 200 ms for single-sample reads and writes (NFR-003).
- A six-generation lineage retrieval is one round trip, not N+1.
- CSV import of 10,000 rows completes within one transaction without exhausting
  memory — streamed, not buffered whole.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Duplicate `human_id` | 409, naming the conflicting sample |
| Amount without unit, or negative | 422, naming the field |
| Aliquot of a Consumed sample | 409, naming the forbidding status |
| Slot occupied during intake | 409, whole registration rolled back |
| Malformed CSV row | 422 with a per-row report; nothing committed |
| Required lineage relation missing | 422, naming the relation |

No error path may leave a sample registered without its audit event, or an
`AliquotLink` without both endpoints.

---

## 7. Security Requirements

**Who may write.** Registration and aliquoting: Technician, Scientist, Project
admin. Type design: Project admin, and only with the design grant (FR-080).
Archiving a type: Project admin. Reader may read only. Auditor may read the trail
and nothing else (CON-006).

**Audit events emitted**: `sample.registered`, `sample.updated`,
`sample.aliquoted`, `sample.derived`, `sample_type.created`,
`sample_type.updated`, `sample_type.archived`, `picklist.updated` — each written
in the same transaction as the change (FR-011, ADR-0003), each carrying the
optional reason for change (FR-070).

**Injection surfaces.**
- *CSV import* is the primary one: content type validated not trusted, size and
  row count bounded, formula injection neutralised, every rejected row reported
  with its line number.
- *Field values* reaching the finder must not be concatenated into SQL — filters
  are parsed into a typed structure (FRD-006).
- *Barcode input* during intake is untrusted: bounded length, validated
  characters, never interpolated into a query.

**Data protection.** No SPHN/USB patient payload may enter OSM (PRO-001). A study
PID is stored only as an opaque token (PRO-002). A DPIA is required before any
USB identifier is processed at all (CON-007). These are enforced by tests that
assert the capability is **absent**, not merely refused.

**Row-level security**: `Sample`, `SampleType`, `Source`, `AliquotLink` and
`AssayRun` each carry an RLS policy keyed on project. A table without one fails a
schema test (AGENTS.md §3).

---

## 8. Dependencies

### Depends On
- FRD-007 (audit) — every write here is audited in-transaction.
- FRD-008 (authorisation) — roles and RLS policies.
- ADR-0001 (OSM is the system of record), ADR-0002 (stack, `Decimal`),
  ADR-0003 (audit inside the domain transaction).

### Depended On By
- FRD-002 (lifecycle) governs the status of what this feature creates.
- FRD-003 (freezer map) stores it; FRD-004 (jobs) operates on it;
  FRD-005 (ELN) references it; FRD-006 (finder) searches it;
  FRD-010 (LabKey publishing) publishes it.

---

## 9. Open Questions

1. Pooling appears in REQ-1 but has no dedicated memory requirement. Is a pooled
   child a third `AliquotLink.kind`, or several `derived` rows? **Needs an ADR
   before implementation** (AGENTS.md §6.5).
2. FR-050 (ZPL label printing) is unresolved in the specification. Label printing
   is referenced by P-INTAKE; it is specified in FRD-003 as a deferred
   integration.
3. Does archiving a sample type cascade to archiving its samples? Assumed no.

---

## 10. Non-Functional Requirements

NFR-003 (API P95 < 200 ms), NFR-004 (100 concurrent users), NFR-005 (one million
samples), NFR-007 (WCAG 2.2 AA). Determinism: re-running an import with the same
file and mapping produces the same result or a clean rejection, never a partial
second copy (AGENTS.md §4).
