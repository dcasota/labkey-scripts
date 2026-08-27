# Feature Requirement Document (FRD): Jobs and Work Queue

**Feature ID**: FRD-004
**Feature Name**: SOP-driven jobs, ordered tasks and a work queue
**Related PRD Requirements**: REQ-4
**Memory Requirements**: FR-004, FR-017, FR-033, FR-034, FR-035, FR-036, FR-059, FR-075, CON-014
**Spec Sections**: §1, §3, §6, §17.2
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

A job template is a reusable SOP skeleton defined without samples. A job binds a
template to a set of samples or a picklist and produces ordered tasks assigned to
users or groups. The queue is how people find the work: my tasks, active jobs, a
board. Due dates escalate before and after they pass, and optimistic locking
stops two people completing the same task twice.

### Value Proposition

The SOP already exists, usually as a PDF nobody opens mid-experiment. Turning it
into a template makes the steps into a checklist that records who did what and
when — which is the same evidence the audit trail and the notebook need anyway.
Without the queue, that evidence is only collected when someone remembers.

### Success Criteria

- A template can be authored once and instantiated against a hundred different
  sample sets without editing.
- Two technicians pressing "complete" on the same task produce one completion and
  one clear refusal — never two completions, never a lost update.
- A task that is about to be late is surfaced before it is late, not after.

---

## 2. Functional Requirements

### 2.1 Job templates without samples (FR-033)

**Description**: A template is an ordered list of task definitions — name,
instructions, expected duration, assignee role or group, optional structured
result fields — with no sample binding.

**Inputs**: template name, ordered task definitions, default assignees.

**Outputs**: a persisted template, audit event `job_template.created`.

**Acceptance Criteria**:
- A template may be **archived** rather than deleted once used (FR-081): hidden
  from pickers, blocked for new jobs, still readable for jobs that ran from it.
- Editing a template does not retroactively change jobs already instantiated
  from it — a job holds a snapshot of the template at start.
- Authoring a template requires the design grant, distinct from the right to run
  one (FR-080).

**Edge Cases**: a template whose only task is assigned to a group with no
members (permitted at design time, warned at instantiation).

### 2.2 Job instantiation (FR-059 P-JOB-START)

**Description**: Bind a template to samples or a picklist; tasks are created,
placed in queues, and the assignees notified.

**Inputs**: template, sample set or picklist reference, due date, assignees
overriding the defaults.

**Outputs**: a `Job`, its ordered `Task` rows, queue entries, notifications, and
audit events.

**Acceptance Criteria**:
- The lifecycle gate (FRD-002) rejects samples in Consumed, Discarded, Shipped
  or Locked status **before** the job is created — not per task, later.
- The pipeline follows trigger → validation → action → audit → notify (FR-056).
- Instantiation is atomic: a job with some of its tasks is not a valid state.

**Edge Cases**: a picklist emptied between selection and start (refused, naming
the empty picklist); a sample locked between selection and start (refused,
naming the sample).

### 2.3 Task execution and completion (FR-036, FR-059 P-JOB-TASK)

**Description**: A task presents its checklist, accepts results, and completes,
advancing the job to the next step.

**Acceptance Criteria**:
- **Optimistic locking on complete**: the request carries the task version;
  a stale version is refused with 409 and the current state, so the second
  technician sees what happened rather than overwriting it.
- Completing out of order is refused unless the template declares the step
  unordered.
- Completion emits `job.task_completed` in the same transaction as the state
  change (FR-011).

**Edge Cases**: an assignee who has lost the role since assignment (refused, and
the task is flagged for reassignment); completing the final task closes the job.

### 2.4 Storage and lineage operations as task steps (FR-075)

**Description**: A task may perform a storage or lineage operation directly —
check-in, check-out, move, aliquot — rather than sending the technician to
another screen.

**Acceptance Criteria**:
- The task delegates to FRD-003 and FRD-001; it does not reimplement occupancy
  or lineage rules. The same database constraint and the same lifecycle gate
  apply.
- A failure in the delegated operation fails the task step with the underlying
  reason (409 slot occupied stays a 409 slot occupied), and the task is not
  marked complete.

*Priority: should, iteration I3.*

### 2.5 Queue views (FR-034)

**Description**: Three views — **my tasks**, **active jobs**, and a **board**
grouped by state.

**Acceptance Criteria**:
- Rows the caller may not read are omitted, not shown redacted (CON-015).
- The board's counts agree with the rows behind them; a count is a query, not a
  cached number that can drift.

### 2.6 Due-date escalation (FR-035)

**Description**: Notify at T−1 (before the due date) and T+1 (after it).

**Acceptance Criteria**:
- The sweep is idempotent: running it twice does not send two notifications for
  the same task and window (AGENTS.md §4).
- Escalation targets the assignee, then the job owner. A task with no valid
  assignee escalates immediately rather than silently never firing.
- P-JOB-BLOCK: a blocked task escalates on the same path (FR-059).

**Edge Cases**: a due date moved into the past (escalates on the next sweep, once);
a task completed between sweep and send (the notification is suppressed).

---

## 3. Data Requirements

| Entity | Key fields |
| --- | --- |
| `JobTemplate` | `template_id`, name, ordered task definitions, archived |
| `Job` | `job_id`, template snapshot, samples/picklist, owner, due date, status |
| `Task` | `task_id`, job, seq, assignee, status, due, **version**, results |

`Task.version` is what optimistic locking compares (FR-036). The template
snapshot on `Job` is what makes §2.1's non-retroactivity true. RLS on every
table, keyed on project.

**A note carried from the release-notes harvest**: LabKey moved its workflow
tables out of `sampleManagement` into a new schema within eighteen months
(CON-018). OSM owns its own schema, but the bridge that publishes job outcomes
must pin the LabKey version it targets — specified in FRD-010.

---

## 4. User Interface Requirements

The **Workflow** area (FR-048): template designer, job start wizard, task detail
with checklist, and the three queue views. The board must be operable by keyboard
alone (NFR-007).

---

## 5. Performance Requirements

- Queue views are the most frequently polled screens in the product; "my tasks"
  must meet the API P95 of 200 ms (NFR-003) at 100 concurrent users (NFR-004).
- Instantiating a job against 1000 samples is one transaction; if it cannot meet
  the latency budget it is an explicit asynchronous job with a progress record,
  never a silently slow request.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Stale task version on complete | **409** with the current state |
| Out-of-order completion | 409, naming the expected step |
| Sample status forbids the job | 409, naming sample and status, before creation |
| Empty picklist at start | 422 |
| Assignee lacks the role | 403, task flagged for reassignment |
| Notification transport down | task state still commits; the notify is retried |

A failed notification must never roll back a completed task. Notification is the
"optional notify" of FR-056's pipeline shape, not part of the domain write.

---

## 7. Security Requirements

**Who may write.** Template authoring: Workflow admin with the design grant
(FR-080). Job instantiation: Scientist, Workflow admin, Project admin. Task
completion: the assignee, or a member of the assigned group, or Workflow admin.
Reassignment: Workflow admin, Project admin. Reader reads; Auditor reads the
trail only (CON-006).

**Audit events emitted**: `job_template.created`, `job_template.archived`,
`job.started`, `job.task_completed`, `job.task_reassigned`, `job.blocked`,
`job.closed` — each in the same transaction as its state change (FR-011,
ADR-0003), each carrying the reason for change where required (FR-070).

**Injection surfaces.**
- *File import*: a task may accept an uploaded result file. Validate the declared
  content type rather than trusting it, bound size and row count, neutralise
  formula injection, report every rejected row with its line number.
- *Structured result fields* are typed; free-text results are stored and rendered
  as text, never interpolated into SQL.
- A task that performs a storage step inherits the **barcode** injection surface
  from FRD-003 §7.

**Prompt injection.** An SOP PDF attached to a template is document content.
Text inside it can ask for a tool; nothing is listening — the assistant tool
allowlist is bound to the session at authentication time, never derived from
document content (CON-012, FRD-011). The retrieval corpus includes SOPs and
templates **by design** (CON-011), which makes this the most likely place for a
hostile document to arrive, and therefore the place the binding must hold.

**Assistant limits**: queue prioritisation is available to an assistant as
**read-only** (FR-066). An assistant may not complete a task on someone's behalf
without explicit confirmation and an administrative scope (FR-045).

---

## 8. Dependencies

### Depends On
- FRD-001 (samples and picklists), FRD-002 (lifecycle gate), FRD-003 (storage
  steps), FRD-007 (audit), FRD-008 (roles, RLS).
- A notification transport — the `notify` service of FR-010.

### Depended On By
- FRD-005 (ELN) — a job step may produce a notebook entry.
- FRD-010 (publishing) — completed jobs and their assay uploads are publishable.

---

## 9. Open Questions

1. **Notification transport is unspecified.** Email, in-app, both? FR-035
   requires escalation but names no channel. This needs an ADR before
   implementation (AGENTS.md §6.5).
2. Structured workflow result fields were flagged as questionable scope in the
   release-notes harvest. Are typed results required for I3, or is free text
   sufficient until a laboratory asks?
3. May a job span projects? Assumed no — RLS makes it awkward and no requirement
   asks for it.

---

## 10. Non-Functional Requirements

NFR-003, NFR-004. **CON-014** gives the job queue an independent acceptance, and
CON-013 sets the I3 gate as "Workflow done at queue" — the queue working, not
merely jobs existing. Idempotency: the escalation sweep and the job-start
pipeline are both safe to re-run (AGENTS.md §4).
