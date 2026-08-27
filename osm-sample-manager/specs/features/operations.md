# Feature Requirement Document (FRD): Operations

**Feature ID**: FRD-012
**Feature Name**: Operations pipelines, deterministic deployment and a runbook
**Related PRD Requirements**: REQ-12
**Memory Requirements**: FR-063, FR-049, FR-062, NFR-006, CON-013
**Spec Sections**: §14, §15, §17.3, §17.4, §19
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Idempotent pipelines for reindexing, audit checkpointing, retention, key rotation
and restore drills; deterministic deployment; and a runbook a second person could
follow.

### Value Proposition

Everything in this document is invisible until the day it is the only thing that
matters. The distinguishing claim OSM makes over its commercial equivalent is
made here: across sixty LabKey release-note pages, **LabKey documents no
point-in-time recovery and no restore drill at any price**. NFR-006 asks for
seven-day PITR, and a drill that proves it — which means there is no prior art to
inherit and nothing to be compatible with.

### Success Criteria

- Every pipeline is safe to run twice. Running one twice is a **test**, not an
  accident to be avoided (AGENTS.md §4).
- A restore drill restores to a chosen point within seven days and the audit
  chain still verifies afterwards.
- A second person can follow the runbook without asking the author a question.
- A failed scheduled run is surfaced, not buried in a log.

---

## 2. Functional Requirements

### 2.1 P-REINDEX (FR-063)

**Description**: Rebuild the finder's search projection.

**Acceptance Criteria**: idempotent; a run in progress does not serve partial
results as complete (FRD-006 §2.4); it can rebuild one project or all; it records
start, end and row counts.

### 2.2 P-AUDIT-CKPT (FR-063, FR-041)

**Description**: The daily checkpoint that anchors each project's hash chain.

**Acceptance Criteria**: running twice for one day produces one checkpoint; a
missed day is detectable and can be backfilled; failure raises rather than
silently skipping — a gap in checkpoints weakens exactly the property the chain
exists for (FRD-007 §2.4).

### 2.3 P-RETENTION (FR-063)

**Description**: Apply each project's retention policy.

**Acceptance Criteria**:
- Retention **never deletes links inside an audit chain**. Expiry seals and
  archives a chain segment with its checkpoint (FRD-007 §3).
- A dry-run mode reports what would be removed and removes nothing.
- Every removal is itself audited.

**Edge Cases**: a sample past retention that is referenced by a signed notebook
(the notebook's immutability wins; the sample is retained and reported).

### 2.4 P-KEY-ROTATE (FR-063)

**Description**: Rotate API keys and any encryption keys.

**Acceptance Criteria**:
- Rotation overlaps: the new key works before the old one stops, so rotation is
  not an outage.
- Credentials come from the environment (ADR-0008); rotation updates the
  environment, and **no key is ever written into the repository**.
- The LabKey bridge key retains its `EditorWithoutDelete` restriction across
  rotation (FRD-008 §2.5).

### 2.5 P-RESTORE-DRILL (FR-063, NFR-006)

**Description**: Prove that a restore works, on a schedule, rather than assuming
it.

**Acceptance Criteria**:
- Restores to a chosen point within the **seven-day** PITR window (NFR-006).
- After restore, the audit chain **verifies** — this is the acceptance, because a
  restore that lands on a broken chain has lost the property the system is built
  around (FRD-007 §10).
- The drill runs against an isolated target, never the live database, and records
  its duration so that a recovery-time estimate is evidence rather than a guess.
- A failed drill is an incident.

### 2.6 Deterministic deployment

**Description**: Dependencies pinned; migrations reversible; the memory dump
byte-stable (AGENTS.md §4).

**Acceptance Criteria**:
- The same inputs produce the same deployment.
- A migration that cannot meet a precondition **aborts** — the `btree_gist`
  example in FRD-003 §3 is the canonical case: it does not continue with an
  application-level check.
- `.sdd/memory.sql` is a deterministic dump so a commit always shows a reviewable
  text diff (ADR-0007).

### 2.7 The runbook

**Description**: Written for a second person, covering deploy, rollback, restore,
key rotation, checkpoint backfill, and what to do when the outbox is stuck
(FRD-010 §4).

**Acceptance Criteria**: it is tested by having someone other than its author
follow it; every command in it is copy-pasteable and every prerequisite is named.

### 2.8 Deferred integrations (FR-049, FR-062)

| Pipeline | Status |
| --- | --- |
| Temperature logger (FR-049) | **could**, open in the specification |
| P-GEO-META, P-UNIPROT, P-BAG-SYNC, P-SPHN-TOKEN (FR-062) | **should**, I7 |

**Acceptance Criteria**: P-GEO-META fetches accession metadata and **no FASTQ**;
P-SPHN-TOKEN handles tokens only, never patient payload (PRO-001, PRO-002). A
temperature logger's absence must not block a storage operation.

---

## 3. Data Requirements

`ScheduledRun` (pipeline, started_at, finished_at, outcome, detail) so that "did
it run, and did it work" is a query rather than a log search. Backup artefacts
live outside the database. Retention policy is a `Project` property (FRD-001 §3).

---

## 4. User Interface Requirements

Within **Admin**: a schedule view showing each pipeline's last run, outcome and
next due, plus manual trigger for those that are safe to trigger (all of them —
they are idempotent). A failed run is visible here without reading logs.

---

## 5. Performance Requirements

- Scheduled work must not starve interactive work: NFR-003 (API P95 < 200 ms) and
  NFR-004 (100 concurrent users) hold **while** a reindex runs.
- A full reindex at one million samples (NFR-005) completes inside its window;
  if it cannot, it is chunked and resumable rather than long and fragile.
- The restore drill records duration, which becomes the recovery-time estimate.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Scheduled run fails | recorded with the reason and **surfaced**; never silent |
| Two runs of one pipeline overlap | second is a no-op, or waits — never a partial concurrent rebuild |
| Migration precondition missing | **abort loudly** (AGENTS.md §4) |
| Restore drill fails | incident; the failure is the finding |
| Retention would break an audit chain | refuse and report |
| Key rotation partially applied | the overlap window makes this recoverable; the run reports which keys moved |

"No silent failures: a failed step is recorded and surfaced. `|| true` is
acceptable only where the outcome is then explicitly checked" (AGENTS.md §4).

---

## 7. Security Requirements

**Who may write.** Pipelines run as service accounts with the narrowest role that
works. Manual trigger: Project admin. Restore and key rotation: an operator role
outside the seven — this is deployment authority, not application authority, and
it is exercised through `scripts/`, which is **the only sanctioned way this
project touches the running LabKey deployment** (AGENTS.md §5).

**Audit events emitted**: `ops.pipeline_started`, `ops.pipeline_finished`,
`ops.retention_applied`, `ops.key_rotated`, `ops.restore_drill` — the operations
layer is audited like everything else, because a retention deletion is a write.

**Credentials**: exclusively from the environment, no defaults, a missing
variable aborts naming it, never a command-line argument, never logged
(ADR-0008, AGENTS.md §3). Key rotation touches every credential the system has
and is therefore the pipeline most likely to leak one — it logs key **ids**,
never key material.

**Backups are the softest target in any system**: a backup of an RLS-protected
database is not RLS-protected. Backup artefacts are encrypted at rest, access to
them is restricted to the operator role, and the restore drill's isolated target
is torn down after the drill rather than left running with production data.

**Malware scanning of uploads** was flagged as questionable scope in the
premium-feature harvest and is unresolved (§9).

---

## 8. Dependencies

### Depends On
- FRD-007 (audit — the checkpoint and the chain that a restore must preserve).
- FRD-006 (finder — the index P-REINDEX rebuilds).
- FRD-008 (credentials and roles), FRD-010 (the outbox an operator unsticks).
- ADR-0007 (project memory as a git-tracked SQL dump), ADR-0008 (credentials).

### Depended On By
- FRD-006 depends on P-REINDEX; FRD-007 depends on P-AUDIT-CKPT. Everything else
  depends on the deployment being deterministic.

---

## 9. Open Questions

1. **Where do backups live, and who can read them?** NFR-006 asks for seven-day
   PITR; no requirement names a location, an encryption scheme or an access
   policy. This needs an ADR — it is the security-relevant half of the claim.
2. How often does the restore drill run? "On a schedule" is not a schedule.
3. Malware scanning of uploaded files: in scope or not?
4. What is the escalation path when a drill fails at 03:00? The runbook needs an
   owner, and no requirement names one.
5. FR-049 (temperature logger) remains open in the specification — protocol,
   device support and alerting are all undecided.

---

## 10. Non-Functional Requirements

**NFR-006** (seven-day PITR) is this feature's headline and the one capability
the harvest found LabKey does not document at any price. NFR-003, NFR-004 and
NFR-005 must hold while these pipelines run — they are the reason "does not
starve interactive work" is an acceptance criterion rather than a hope.
**CON-013** places these at I7, the last iteration, which is a risk worth naming:
the restore drill proves a property the project has claimed since I0, and it is
scheduled last.
