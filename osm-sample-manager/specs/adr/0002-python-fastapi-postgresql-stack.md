# ADR-0002: Python, FastAPI And PostgreSQL As The Implementation Stack

**Date**: 2026-08-26
**Status**: Accepted

## Context

ADR-0001 makes OSM a standalone system, so the stack is a free choice
constrained only by the specification and the operating environment.

The specification fixes one element: §2 requires *"PostgreSQL mit RLS"*. Nothing
else is prescribed. §10 requires a REST API with an OpenAPI description (§13, I0
lists "Auth, Audit, OpenAPI" as the first deliverable). §18 requires an MCP
server whose tools mirror REST semantics. §14 sets API P95 < 200 ms at 100
concurrent users.

The environment already provides PostgreSQL 18.6, Python 3.11.13, Node 24.14
and JDK 21/25 (verified V-003). The user's existing automation is bash plus
Python; the project tooling written in this bootstrap (`tools/memory.py`) is
Python.

## Decision Drivers

- §2 fixes PostgreSQL, and PostgreSQL 18.6 is already installed and hosting
  LabKey.
- §18's MCP server needs a mature MCP SDK.
- §14's latency target is modest for any of the candidates; correctness and
  auditability matter more than raw throughput.
- The maintainer's demonstrated fluency is bash and Python.
- Row-level security (§2) is a PostgreSQL feature and must not be abstracted
  away by the data layer.

## Considered Options

### Option 1: Python with FastAPI, SQLAlchemy 2.x and Alembic

**Description**: Async FastAPI services, SQLAlchemy Core/ORM for persistence
with explicit transaction boundaries, Alembic for migrations, pytest for tests.

**Pros**:
- OpenAPI is generated from the route signatures, so §13's I0 deliverable is
  structural rather than a maintenance burden.
- The official MCP Python SDK is first-class, which §18 needs.
- Pydantic gives server-side request validation at the boundary by default,
  which is a security requirement, not a convenience.
- Matches the maintainer's existing tooling and the HuggingFace client
  ecosystem §18 will draw on.
- SQLAlchemy does not hide the connection, so `SET LOCAL ROLE` and RLS session
  variables remain expressible.

**Cons**:
- Slower per-request than a compiled runtime.
- Async plus ORM is an easy place to get transaction scoping wrong, and §2's
  same-transaction audit rule makes that mistake expensive.

### Option 2: Java with Spring Boot

**Description**: Spring Boot services, JPA/Hibernate, Flyway, JUnit.

**Pros**:
- Same runtime family as LabKey, so operational knowledge transfers.
- Strong typing and a mature transaction abstraction.
- Highest raw throughput of the three.

**Cons**:
- Heaviest toolchain; the enlistment build already demonstrates how much
  Gradle/JDK version management the environment costs.
- MCP SDK support is less mature than Python's.
- Furthest from the maintainer's existing automation, which is the practical
  risk that matters for a long-running solo project.

### Option 3: TypeScript with NestJS on Node

**Description**: NestJS services, Prisma or Drizzle, Vitest.

**Pros**:
- One language across API and UI, since §12's UI will be TypeScript regardless.
- Good async ergonomics and fast startup.

**Cons**:
- Prisma's abstraction fights PostgreSQL RLS; raw session variables need escape
  hatches.
- Numeric handling needs care for the amount arithmetic in §17.1 (aliquot
  splitting), where float semantics are a correctness hazard.
- MCP SDK is available but the ecosystem around scientific data handling is
  thinner than Python's.

## Decision Outcome

**Chosen Option**: Option 1 — Python with FastAPI, SQLAlchemy 2.x and Alembic.

**Rationale**:

- OpenAPI generation and Pydantic boundary validation directly satisfy two
  requirements (§13 I0, and the server-side validation obligation) rather than
  merely enabling them.
- The MCP requirement in §18 is not optional and Python has the strongest SDK.
- §14's 200 ms P95 at 100 concurrent users is comfortably reachable in Python;
  choosing a faster runtime would buy headroom the specification does not ask
  for, at the cost of maintainability for the one person who maintains this.
- SQLAlchemy leaves the connection visible, which is what RLS needs.

Frontend: React with TypeScript and Vite, as a separate client of the same API
(§12, and CON-005 — the UI gets no privileged back door).

## Consequences

### Positive

- OpenAPI, request validation and the MCP adapter all come from one type model.
- Alembic migrations give the deterministic rebuilds the project requires.
- `Decimal` is the natural numeric type for sample amounts, avoiding float drift
  in aliquot arithmetic.

### Negative

- Async transaction scoping must be enforced by convention and tested, because
  §2's same-transaction audit rule fails silently if a session is reused wrongly.
  A dedicated unit-of-work helper and a test that asserts audit-and-domain
  atomicity are therefore mandatory, not optional.
- Python's packaging needs pinning discipline for deterministic rebuilds.

### Neutral

- The stack shares nothing with LabKey's Java runtime. Given ADR-0001 that is
  intended; the only contact surface is HTTP.

## Implementation Notes

- Pin with `pyproject.toml` plus a lock file. A rebuild that resolves different
  versions is not deterministic.
- Amounts use `NUMERIC` in PostgreSQL and `Decimal` in Python throughout.
- The unit-of-work helper is the only sanctioned way to open a write
  transaction, and it emits the audit event before commit.

## References

- `specs/source/spezifikation-extract.md` §2, §10, §12, §13, §14, §18
- Memory: `FR-012`, `FR-011`, `NFR-003`, `NFR-004`, `CON-005`
- Verification: `V-003`
