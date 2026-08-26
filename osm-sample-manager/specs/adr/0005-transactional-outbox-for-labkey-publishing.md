# ADR-0005: Transactional Outbox For LabKey Publishing

**Date**: 2026-08-26
**Status**: Accepted

## Context

§3 defines `PublishOutbox(outbox_id: target, state)`. §16.2 says the
`labkey-bridge` drains `osm_publish_queue` on the events `sample.committed`,
`assay.uploaded` and `notebook.signed`, that failures are stored as `FAILED`
including the HTTP response body, and that `osm_id` provides idempotency.
§17.3 defines the `P-LK-*` pipelines the bridge runs.

LabKey is a separate system reached over HTTP. It can be down, slow, or reject a
payload. The question is what happens to an OSM write whose publish fails.

## Decision Drivers

- An OSM write must never fail because LabKey is unavailable; ADR-0001 makes
  LabKey downstream, and a downstream system must not be able to block the
  system of record.
- A publish must never be lost, because divergence between OSM and LabKey is
  silent and discovered late.
- Retries must not duplicate rows in LabKey (§16.2 `osm_id`).
- Failures must be inspectable, including the HTTP body (§16.2).

## Considered Options

### Option 1: Publish synchronously inside the domain transaction

**Description**: On commit, call LabKey; roll back if it fails.

**Pros**:
- OSM and LabKey are never out of step.
- No extra machinery.

**Cons**:
- LabKey downtime becomes OSM downtime. Disqualifying.
- An HTTP call inside a database transaction holds locks for the duration of a
  network round trip.
- No true atomicity anyway: the call can succeed and the transaction still roll
  back, producing exactly the duplicate the design is trying to avoid.

### Option 2: Fire an asynchronous job after commit

**Description**: After committing, enqueue to a job runner (Celery, RQ,
`LISTEN/NOTIFY`).

**Pros**:
- OSM writes stay fast and independent of LabKey.
- Mature tooling.

**Cons**:
- The enqueue is not in the transaction. A crash between commit and enqueue
  loses the publish permanently, and nothing detects it — the exact silent
  divergence this must prevent.
- Adds a broker to operate.

### Option 3: Transactional outbox drained by a worker

**Description**: The domain transaction inserts an `osm_publish_queue` row
alongside the domain write. A separate worker polls for `PENDING` rows, calls
LabKey, and moves each row to `SENT` or `FAILED` with the response body.

**Pros**:
- The outbox row commits atomically with the domain write, so a publish can
  never be lost — the same property §2 gives the audit trail, applied here.
- LabKey downtime only grows the queue.
- `FAILED` rows with their HTTP bodies are exactly what §16.2 asks for.
- No broker; PostgreSQL is the queue, and it is already required by §2.
- Retry is safe when combined with `osm_id` idempotency.

**Cons**:
- Polling adds latency between commit and publish.
- The worker needs leader election or `SELECT ... FOR UPDATE SKIP LOCKED` so two
  workers do not publish the same row twice.

## Decision Outcome

**Chosen Option**: Option 3 — transactional outbox.

**Rationale**:

- It is the only option where the publish intent and the domain write share a
  commit, which is what makes "never lost" a property rather than a hope.
- §3 already names `PublishOutbox` as a domain entity, so the specification
  anticipates this pattern.
- It removes a broker from the deployment, which matters for a system one person
  operates.
- `FOR UPDATE SKIP LOCKED` is a well-understood PostgreSQL idiom that makes the
  worker horizontally scalable without coordination.

## Consequences

### Positive

- Publishes survive LabKey downtime, OSM restarts and worker crashes.
- Publish lag is observable: the age of the oldest `PENDING` row is a single
  metric that says whether the bridge is healthy.
- `FAILED` rows retain the HTTP body, so triage does not require reproducing the
  failure — which is also what §18.1 wants the assistant to read.

### Negative

- Eventual consistency between OSM and LabKey. The UI must not imply that a
  committed sample is already in LabKey; publish state is shown explicitly
  (`osm.labkey.publish_status` in §10 exists for this).
- Polling latency, bounded by the poll interval.

### Neutral

- The same outbox serves any future publish target; `target` is already a column
  in §3's definition.

## Implementation Notes

- Idempotency: every published row carries `osm_id`. The bridge upserts on
  `osm_id` rather than inserting, so a retry after an ambiguous timeout
  converges instead of duplicating. This is the case that matters — a response
  lost in transit looks identical to a rejected request.
- Retries use exponential backoff with a cap and a maximum attempt count; a row
  that exhausts its attempts stays `FAILED` and is never silently dropped.
- PHI is stripped at the point the outbox row is built (§16.2, PRO-003), not at
  publish time, so a payload containing PHI is never written to the queue at
  all.

## References

- `specs/source/spezifikation-extract.md` §2, §3, §10, §16.2, §17.3, §18.1
- Memory: `FR-021`, `FR-054`, `FR-055`, `PRO-003`
