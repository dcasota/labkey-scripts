# Gap analysis: OSM vs commercial LabKey Sample Manager vs LabKey CE

The full inventory is in the memory database (60 rows):

```bash
tools/memory.py list features
tools/memory.py query "SELECT id,area,name,commercial,ce_support,gap FROM features ORDER BY area,id"
```

This page is the headline. Every claim about LabKey CE is verified against
`/root/scicore` or the running server (see `docs/labkey-ce-ground-truth.md`);
every claim about the commercial product carries a labkey.org or labkey.com URL.

Two companion pages carry the detail, both `doc`-grade and both saying so on
their face:

- [`premium-feature-gap.md`](premium-feature-gap.md) — 140 features LabKey
  withholds from Community Edition, each with the edition that provides it, the
  documentation URL, and whether OSM must reimplement it. From a 265-page walk
  of the documentation tree.
- [`labkey-release-notes-survey.md`](labkey-release-notes-survey.md) — the same
  boundary along the time axis: when each capability appeared and which side of
  the paywall it landed on. From 60 server release-notes pages (2007-2026) and
  the 83-section LIMS Suite page.

Neither overturned anything below. Both sharpened it, and together they added
19 requirements (`FR-068`-`FR-081`, `NFR-008`, `CON-015`-`CON-018`) and 16
backlog items (`PR-039`-`PR-054`).

## Headline

**LabKey Community Edition provides the sample *data model*. It provides
almost none of the sample *management application*.**

Of 60 catalogued capabilities:

| LabKey CE support | Count | What it means |
| --- | --- | --- |
| `native` | 7 | CE genuinely provides it |
| `partial` | 7 | The server supports it but the UI or an edition gate blocks it |
| `absent` | 46 | Not present at any level |

And the boundary is sharper than "premium features". **Sample management is a
separate product.** The freezer, the workflow queue, the notebook, the picklist,
the finder, the sample timeline and the sample status UI are documented in the
`/limshelp` wiki, badged against Sample Manager and LIMS editions rather than
LabKey Server editions, and **no tier of that product is free** — there is no
"Community" chip in its badge vocabulary at all. What LabKey Server's own
premium editions add on top is infrastructure: ETL, SSO, PHI enforcement,
compliance logging, external data sources, MCP. Not sample management.

The 22 absent capabilities include every one that makes a sample manager a
sample manager: storage hierarchy, box layouts, check-in/check-out, sample
status enforcement, picklists, the sample finder, workflow jobs, and the ELN.

**In the commercial product those same capabilities are the paywall.** LabKey
sells them in a five-tier LIMS Suite starting at **USD 6,540/year for five
users** (Sample Manager Starter) and reaching **USD 59,400/year** (Biologics
LIMS). ELN, workflow, assay management and API access require **SM Professional
at USD 13,140/year**. Electronic signatures, ETL, SSO and the MCP server require
**LIMS Enterprise**.

So the gap OSM fills is not a gap in LabKey's engineering. It is the deliberate
boundary between LabKey's free data platform and its commercial application
layer. That is why ADR-0001 builds OSM standalone rather than as a CE module:
there is no CE substrate to extend.

## What CE genuinely gives you (7 native)

These are worth knowing precisely, because they define what the publish bridge
can lean on rather than reimplement downstream.

| Capability | Evidence |
| --- | --- |
| Sample types with custom fields | `property-createDomain.api` with kind `SampleSet`; `ExpSampleType.java` |
| Naming patterns and ID generation | `NameGenerator.java` — `genId`, `sampleCount`, `daily/weekly/monthly/yearlySampleCount`, `randomId`, `withCounter`, lineage refs |
| Lineage and derivation | `exp.Edge`, `exp.MaterialAncestors`, `experiment-lineage.api`, `experiment-derive.api` |
| Sample timeline audit | `SampleTimelineEvent`, registered unconditionally, `DETAILED` by default with `oldRecordMap`/`newRecordMap` |
| Client APIs and API keys | Full HTTP API; API keys support **restriction roles** |
| Full-text search over samples | Lucene 10.5; samples indexed as `material:<rowId>` |
| Open source, zero licence cost | Apache 2.0 |

The aliquot columns deserve a special mention: `exp.Material` carries
`RootMaterialRowId`, `AliquotedFromLSID`, `IsAliquot`, `AliquotCount`,
`AliquotVolume`, `StoredAmount`, `Units` and `AvailableAliquotVolume` natively.
The *storage* semantics that consume them are what live in the absent
`inventory` module.

## The five traps: `partial` means "looks present, enforces nothing"

This is the most important section of this document, because each of these
would produce a plausible but wrong implementation.

### 1. Sample status is not enforced in CE

`SampleStatusService` has no registered provider, so CE falls back to
`DefaultSampleStatusService`, whose `isOperationPermitted()` **returns `true`
unconditionally** (`.../api/qc/SampleStatusService.java:84`).

A sample marked `Consumed` in LabKey CE can still be edited, aliquoted and
derived. The three state types exist in `exp.SampleStateType`
(`Available`, `Consumed`, `Locked`) and `exp.SampleStatus` is empty. Status in
CE is a label, not a rule.

OSM §3 requires eight statuses with real transitions. Neither CE nor the
commercial product provides them — SM offers admin-defined names *within* the
same three types.

### 2. PHI tagging in CE masks nothing

The `PHI` enum, `PhiColumnBehavior` (`show|blank|remove`) and the call sites in
`FilteredTable.applyTableRules` all exist. No module registers a
`ComplianceService`, so `DefaultComplianceService` passes everything through
with `getMaxAllowedPhi()` = `Restricted`.

**PHI tags survive export and import and provide no protection whatsoever.**
Anyone who tags a column PHI in CE and assumes it is masked is wrong.

OSM sidesteps this: §1 forbids PHI in OSM at all and §16.2 requires stripping
before publish (PRO-001, PRO-003). The outbox strips at row-build time
(ADR-0005), so PHI never reaches the queue, let alone LabKey.

### 3. The barcode field type is blocked only in JavaScript

`STORAGE_UNIQUE_ID_CONCEPT_URI` drives a DbSequence-backed auto-generated value
server-side. The bundled field editor refuses the type when
`isCommunityDistribution()`, but **there is no server-side gate**.

`property-createDomain.api` with
`conceptURI: "http://www.labkey.org/types#storageUniqueId"` creates a working
barcode field in CE. This is a genuine capability the UI simply does not offer,
and it means the publish path can create real barcode fields downstream.

### 4. MCP exists in CE but is inert

CE contains `McpService`, `McpContext`, `AbstractAgentAction`, and tool
definitions in `CoreMcp`, `QueryMcp` and `SearchMcp`. No implementation is
registered, and `SearchModule.java:136-141` has its registration commented out
("Search endpoints are not ready for prime time"). `McpService.get()` returns
`NoopMcpService` with `isEnabled()` = `false`.

There is no working MCP server in this build.

### 5. `InventoryService` returns `null` rather than failing

Every call site is null-guarded (`ExpMaterialTableImpl.java:900`,
`SampleTypeUpdateServiceDI.java:418`). Storage columns silently do not appear.
Code that probes for freezer support sees absence, not an error.

## Where OSM must build from nothing (9 high-gap)

| Area | Capability | Why it is hard |
| --- | --- | --- |
| storage | Freezer/storage hierarchy | No CE schema; §5 needs 5 levels with 1:1 physical fidelity |
| storage | Check-in / check-out / move | §5 needs atomicity and 409-on-conflict, which SM does not document |
| workflow | Jobs, tasks, templates | §6 adds optimistic locking on complete and T-1/T+1 escalation |
| eln | Notebook | Absent from CE entirely (`labbook` module missing) |
| eln | Review, signing, locking | §7 binds a JSON hash to the signature; SM does not |
| search | Faceted sample finder | CE has **no faceting at all**; §8 demands P95 < 300 ms at 10⁶ samples |
| audit | Tamper-evident hash chain | Neither CE nor SM chains audit events |
| security | Row-level security | Neither CE nor SM has RLS on samples |
| llm | MCP with write tools | SM's MCP is read-only and premium; §18 needs confirmed writes and `llm.invoke` |

## Where OSM goes beyond the commercial product

These are recorded as `commercial: no` in the inventory. They are not
gold-plating; each is a specification requirement.

| Capability | Commercial SM | OSM requirement |
| --- | --- | --- |
| **Tamper-evident audit** | No chaining anywhere; Part 11 support comes via ELN signing | §9: SHA-256 chain, daily checkpoint, trail export (ADR-0003) |
| **Row-level security** | Container/folder partitioning only | §2: PostgreSQL RLS (I5 acceptance gate) |
| **TTL slot reservation** | Check-out holds a slot indefinitely | §5: bounded reservation, auto-expiring (ADR-0004) |
| **Atomic box move** | Not documented | §5, §17.1 `P-BOXMOVE` |
| **Due-date escalation** | Notifies on readiness, not on due dates | §6: T-1 / T+1 |
| **Eight-status lifecycle** | Three status types with custom names inside them | §3: Registered → Available → Reserved → In Process → Consumed \| Locked \| Discarded \| Shipped |
| **MCP write tools with audit** | Read-only, premium-only | §10, §18: `confirm=true` + `osm.admin.write`, `actor_type=mcp`, `llm.invoke` |
| **ZPL label printing** | BarTender only; no ZPL/Zebra documented | §15 open point |
| **Signature bound to a content hash** | Re-auth and locking, no content hash | §7: JSON hash bound to the signer |
| **Zero licence cost** | USD 6,540–59,400/year | §1: Apache-2.0 / CC-BY-4.0 |

Two of these deserve comment.

**LabKey is candid about its MCP security model**: *"What limits the agent is
the API key you give it, not anything built into the MCP Server."* OSM §18 takes
the opposite position — the tool surface itself is constrained, prohibited
operations are not exposed as tools at all, and the allowlist is bound to the
session rather than derived from anything the agent reads (ADR-0006, CON-012).

**SM's "find empty slots" is not a feature.** Free space is emergent from
per-level capacity counters and a capacity bar. §18.1 wants an assistant
`find_empty` tool, which requires a real query. ADR-0004's slot-assignment
model makes that a straightforward `NOT EXISTS` over live assignments.

## What LabKey CE still buys us

ADR-0001 keeps LabKey CE as the downstream publish target, and that is not a
consolation prize. §16.1 maps every OSM object onto a CE module, and CE provides
each mapping natively:

| OSM object | LabKey CE target | Endpoint |
| --- | --- | --- |
| Sample, Aliquot, Lineage | `experiment` Sample Types | `property-createDomain.api` + `query-import.api` |
| Source | `experiment` Data Classes | `property-createDomain.api` + rows |
| AssayRun | `assay` | `assay-importRun.api` |
| Catalogs, job read-model | `list` | IntList + `query-import.api` |
| File pointers | `pipeline` / `filecontent` | WebDAV `@files` |
| SOPs, source cards | `wiki` | `wiki-saveWiki.api` |
| Charts | `visualization` | `visualization-saveVisualization.api` |
| Supplementary trail | `audit` | never replaces the OSM trail (§16.1, CON-008) |

So the institution keeps LabKey as its analysis, sharing and long-term data
surface, and OSM supplies the LIMS layer LabKey CE does not have — without the
USD 6,540–59,400/year the equivalent commercial capability costs.

## Community Edition has been losing ground

Not a static boundary. Over five years CE *lost* sample-domain capability
(`labkey-release-notes-survey.md` §6.2):

| Release | Removed from Community Edition |
| --- | --- |
| 21.3 (Mar 2021) | **Specimen Repository** — *"removed from all standard distributions (Community, Starter, Professional, and Enterprise)"* |
| 21.7 (Jul 2021) | Specialty Assays — ELISA, ELISpot, NAb, Luminex, Flow |
| 22.3 (Mar 2022) | Panorama; Mass Spectrometry (MS2) |
| 25.3 (Mar 2025) | **FreezerPro integration**; **SampleMinded integration** |
| 25.11 (Nov 2025) | Advanced folder-archive import options |

The specimen removal matters most: it was the last vestige of vial and
storage-location tracking available to a CE user, and with FreezerPro and
SampleMinded gone too, **since March 2025 CE has had no freezer capability from
any direction.**

What CE *gained* over the same period is audit, security and API hygiene —
forced detailed audit on Samples, Sources, Data Classes and Assay Data (25.11),
a per-folder "See Audit Log Events" role and grid-view auditing (26.3),
role-restricted API keys described as *"a way to impose appropriate limits on
AI agents, tools, and scripts"* (26.7). Every one of those is something the OSM
publish bridge depends on. None is a sample-management feature.

That is a coherent picture, and it is the one ADR-0001 assumes.

## Sources

Commercial product: labkey.com/pricing, and the labkey.org `/limshelp` wiki,
whose every page carries an authoritative `Available in: <editions>` badge —
`createSampleType`, `sampleIDs`, `aliquots`, `aliquotIDs`, `sampleStatus`,
`createFreezer`, `manageUnits`, `checkout`, `storeFreezer`, `freezerDetails`,
`uniqueStorageIds`, `barTender`, `setupBarTender`, `workflow`, `jobTemplate`,
`manageJobs`, `notifications`, `sampleELN`, `elnReview`, `elnAmend`,
`sampleFinder`, `samplePicklist`, `sampleTimeline`, `audits`, `limsSuite`,
`limsEnterprise`, `enterpriseGov`, `crossFolder`, plus `/Documentation` pages
`dataClass`, `eSignatures`, `compliance`, `mcp`, `releasenotes267`.

Community Edition is defined by its build files rather than by marketing:
`gradle/settings/community.gradle` plus `base.gradle` list 16 modules. The
labkey.com edition matrix contradicts the docs on Specialty Assays and ELN in
Community; the build files and the doc badges are authoritative.

LabKey CE behaviour: `docs/labkey-ce-ground-truth.md`, verifications `V-001`
through `V-018`, research findings `RF-001` through `RF-015`.
