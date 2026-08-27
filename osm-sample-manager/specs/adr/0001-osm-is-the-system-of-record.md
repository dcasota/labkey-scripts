# ADR-0001: OSM Is The System Of Record And LabKey CE Is A Downstream Publish Target

**Date**: 2026-08-26
**Status**: Accepted

## Context

The project was framed as building "an enterprise-worthy Sample Manager for
LabKey Community Edition". The specification that governs the work says
something materially different, and says it four times in §1 alone:

- *"Open-Source-Eigenlösung ... Unabhängig von LabKey-Produkten."*
- *"Kein LabKey-UI-Klon."*
- *"LabKey ist Downstream."*
- *"LabKey-Publish ohne addWebPart."*

§16 makes the direction explicit: *"OSM ist System of Record. LabKey CE ist
Publish-Ziel."* §12 requires OSM's own UX with eight top-level areas. §2
describes eleven OSM services with their own PostgreSQL database.

This reading is not a matter of taste. It decides whether the deliverable is a
LabKey module or a standalone system, and therefore decides the entire
architecture. Getting it wrong late would be unrecoverable.

The environment reinforces the reading. Verified against the running server
(V-001, V-002): LabKey CE 26.7.5 exposes no `inventory`, `storage`, `freezer`,
`workflow` or `eln` schema, and the `exp` schema's sample status vocabulary has
exactly three state types (`Available`, `Consumed`, `Locked`) against the eight
lifecycle statuses §3 requires. The freezer map, the job queue and the ELN — the
three capabilities the spec gives their own acceptance gates in §19 — have no
LabKey CE substrate at all.

## Decision Drivers

- The specification is the contract, and it is unambiguous.
- The three headline capabilities have no LabKey CE foundation to extend.
- §14 sets latency and scale targets (API P95 < 200 ms, search P95 < 300 ms at
  10⁶ samples, 81 000 slots rendered smoothly) that must be owned end to end.
- §7 and §9 require immutability and a tamper-evident hash chain that a
  downstream system cannot be trusted to preserve.
- §18 requires MCP tools and an LLM audit trail; LabKey's own MCP support is
  premium-only and therefore unavailable in CE.
- The user already has substantial tooling for *publishing into* LabKey
  (`/root/install-labkey-*.sh`), which is exactly the downstream role.

## Considered Options

### Option 1: Build OSM as a file-based or Java LabKey module

**Description**: Implement sample management inside LabKey CE as a module,
extending `exp.material`, adding an inventory schema, and rendering the UI in
LabKey's page framework.

**Pros**:
- Reuses LabKey's authentication, container security and audit infrastructure.
- Sample types, lineage and aliquots already exist in `exp` (verified: the
  `exp.Materials` table carries `RootMaterialRowId`, `AliquotedFromLSID`,
  `IsAliquot`, `StoredAmount`, `Units`).
- One system to operate rather than two.

**Cons**:
- Directly contradicts the specification (§1 "Kein LabKey-UI-Klon", §16 "LabKey
  ist Downstream").
- The freezer map, job queue and ELN would be built from nothing anyway, inside
  a framework not designed for them.
- Couples OSM's release cycle to LabKey's, and to a Java/Gradle enlistment.
- LabKey's container-and-role security model has no row-level security; §2
  and §13 (I5) require RLS.
- An immutable, hash-chained audit is not achievable when another system's
  code can write to the same tables.

### Option 2: Build OSM standalone, with LabKey CE as a publish target

**Description**: OSM owns its own PostgreSQL database, services, API and UI.
A `labkey-bridge` service drains a transactional outbox and publishes committed
samples, uploaded assays and signed notebooks into LabKey CE using the documented
HTTP APIs.

**Pros**:
- Matches the specification exactly, including §16's module mapping table and
  the `P-LK-*` pipelines in §17.3.
- OSM owns its own latency, scale and immutability guarantees.
- LabKey CE remains a first-class consumer for the data, so nothing the
  institution already does with LabKey is lost.
- The bridge is replaceable; a second publish target costs one adapter.

**Cons**:
- Two systems to operate and secure.
- Sample types, lineage and aliquots must be reimplemented even though LabKey CE
  provides them natively.
- Data exists in two places, so the publish path must be idempotent and its
  failures must be visible.

### Option 3: Hybrid — LabKey CE as the sample store, OSM services alongside

**Description**: Keep samples in `exp.material` via the LabKey API, and build
only storage, workflow and ELN as OSM services that reference LabKey sample ids.

**Pros**:
- Avoids reimplementing sample types and lineage.
- Less duplicated data than Option 2.

**Cons**:
- Every OSM write becomes a distributed transaction across two databases, which
  makes §2's *"jede Schreiboperation auditiert in derselben Transaktion"*
  impossible to honour.
- §5's atomic check-in/move and 409-on-conflict need slot and sample state in
  one transaction.
- The audit chain would have gaps wherever LabKey mutated a sample directly.
- Worst of both worlds operationally: coupled to LabKey's uptime *and* running
  separate services.

## Decision Outcome

**Chosen Option**: Option 2 — OSM standalone, LabKey CE downstream.

**Rationale**:

- The specification is explicit and repeated; Option 1 and Option 3 would each
  require overruling it.
- The single most load-bearing requirement, §2's *every write is audited in the
  same transaction*, is only satisfiable when OSM owns the transaction boundary.
  That eliminates Option 3 on correctness grounds, not preference.
- The three capabilities with independent acceptance gates in §19 — freezer map,
  job queue, ELN — must be built regardless of the option chosen. Option 1's
  main advantage therefore applies to a minority of the work.
- Option 2 keeps LabKey CE valuable: §16.1 maps every OSM object onto a LabKey
  module, so LabKey remains the institutional analysis and sharing surface.

The framing "a Sample Manager for LabKey CE" is honoured as *a sample manager
whose data lands in LabKey CE*, which is what §16 describes, rather than *a
sample manager implemented inside LabKey CE*, which §1 forbids.

## Consequences

### Positive

- OSM controls its own schema, so RLS (§2), the eight-status lifecycle (§3), the
  five-level storage hierarchy (§5) and slot exclusion constraints (§5) are all
  expressible directly.
- The audit hash chain (§9) is unbroken because only OSM writes to OSM.
- Performance targets (§14) are owned end to end and can be benchmarked.
- LabKey CE stays on its own upgrade cycle; a LabKey upgrade cannot break OSM.

### Negative

- Sample types, naming patterns, lineage and aliquots are reimplemented despite
  existing in LabKey CE's `exp` schema. This is real, quantified duplicated
  effort (see the gap analysis: those are the `native` rows).
- Two systems to deploy, back up and secure.
- Data lives in two places. The publish path must be idempotent (§16.2
  `osm_id`), and publish failures must surface rather than silently diverge.

### Neutral

- The `labkey-bridge` is the only component that knows LabKey exists. Everything
  else in OSM is unaware of it, so a future second target is additive.
- LabKey CE's own audit trail continues to exist and is explicitly a supplement,
  never a replacement (§16.1: *"nicht OSM ersetzen"*).

## Implementation Notes

- The bridge uses the API conventions already proven in the user's scripts:
  session bootstrap via `login-whoAmI.api` for the CSRF token, `-k` for the
  self-signed loopback certificate, `--max-redirs 0`, and no `curl -f` so that
  4xx bodies remain readable.
- §16 forbids `addWebPart`. Portals are delivered as `folder.xml` archives.
  The user's own scripts document why `addWebPart` misbehaves on CE 26.

## References

- `specs/source/spezifikation-extract.md` §1, §2, §12, §16, §19
- `docs/labkey-ce-ground-truth.md`
- Memory: `CON-002`, `CON-003`, `CON-008`, `FR-009`, `FR-021`, `PRO-004`
- Verifications: `V-001`, `V-002`
