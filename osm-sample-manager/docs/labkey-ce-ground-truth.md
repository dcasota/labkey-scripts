# LabKey CE 26.7.5 — verified ground truth

Everything on this page was established by reading the source under
`/root/scicore` or by calling the running server at `https://127.0.0.1:8443`.
Nothing here is inferred from documentation alone. Each claim carries its
evidence. The corresponding rows are in the memory database
(`tools/memory.py list research`, `tools/memory.py list verifications`).

Nothing under `/root/scicore` was modified to produce this.

## Version and build

| Fact | Value | Evidence |
| --- | --- | --- |
| LabKey version | 26.7.5 | `/root/scicore/gradle.properties:47` `labkeyVersion=26.7.5` |
| Client API version | 7.3.0 | `/root/scicore/gradle.properties:48` |
| Core schema version | 26.007 | `/root/scicore/build/deploy/modules/core/config/module.xml` |
| Java source level | 25 | `/root/scicore/gradle.properties` `sourceCompatibility=25` |
| Gradle plugin | `org.labkey.build.module` 9.2.0 | `/root/scicore/settings.gradle` |
| Deployed modules | 43, **zero premium** | `/root/scicore/build/deploy/modules/` |

Deployed module families: platform (23), commonAssays (10),
DiscvrLabKeyModules (8), LabDevKitModules (2), targetedms (1), scicoreBrand (1).

## The premium boundary

This is the most consequential finding. LabKey CE ships the **service
interfaces** for its premium capabilities, with no implementation registered.
Each degrades to a no-op rather than failing, which makes the absence easy to
miss.

| SPI | State in CE | Evidence |
| --- | --- | --- |
| `InventoryService` (Freezer Manager) | interface only; `get()` returns `null`, no `setInstance` caller | `/root/scicore/server/modules/platform/api/src/org/labkey/api/inventory/InventoryService.java` |
| `SampleStatusService` | no provider registered; falls back to `DefaultSampleStatusService` whose `supportsSampleStatus()` returns `false` and `isOperationPermitted()` always returns `true` | `.../api/qc/SampleStatusService.java:84` |
| `ComplianceService` (PHI masking) | no registrant; `DefaultComplianceService` no-ops, `getMaxAllowedPhi()` = `Restricted` | `.../api/compliance/ComplianceService.java` |
| `McpService` | no registrant; `get()` returns `NoopMcpService`, `isEnabled()` = `false` | `.../api/mcp/McpService.java` |

`ProductFeature` enumerates the premium features and their owning modules:
`FreezerManagement("inventory")`, `ELN("labbook")`, `BiologicsRegistry("biologics")`,
`SampleManagement("sampleManagement")`, `Media("recipe")`
(`.../api/settings/ProductFeature.java`).

**`SampleStatusService` deserves emphasis.** `isOperationPermitted()` returning
`true` unconditionally means CE does not enforce sample-status rules at all. A
sample marked `Consumed` can still be edited, aliquoted or derived. Any status
semantics must be enforced by whatever system owns them — which under ADR-0001
is OSM.

### MCP in CE

The MCP *framework* is present — `McpService`, `McpContext`,
`AbstractAgentAction`, plus tool definitions in `CoreMcp.java`
(`listContainers`, `setContainer`, `listModules`), `QueryMcp.java`
(`listSchemas`, `listTables`, `getTableMetadata`, `getQuerySql`, `validateSql`,
`executeSql`) and `SearchMcp.java` (`siteSearch`, `listSearchCategories`).
But no implementation is registered, and `SearchModule.java:136-141` has its
registration commented out with the note *"Search endpoints are not ready for
prime time"*. **There is no working MCP server in this build.**

## What CE genuinely provides

### Sample Types, naming patterns and aliquots — fully present

`exp.Material` carries the aliquot and amount columns
(`/root/scicore/server/modules/platform/experiment/resources/schemas/dbscripts/postgresql/exp-0.000-25.000.sql:323-368`):

```sql
ALTER TABLE exp.Material ADD COLUMN AliquotedFromLSID LSIDtype NULL;
ALTER TABLE exp.Material ADD COLUMN SampleState INT;
ALTER TABLE exp.Material ADD COLUMN AliquotCount INTEGER NULL;
ALTER TABLE exp.Material ADD COLUMN AliquotVolume FLOAT NULL;
ALTER TABLE exp.Material ADD COLUMN AliquotUnit VARCHAR(10) NULL;
ALTER TABLE exp.Material ADD COLUMN MaterialExpDate TIMESTAMP NULL;
ALTER TABLE exp.Material ADD COLUMN StoredAmount DOUBLE PRECISION;
ALTER TABLE exp.Material ADD COLUMN Units VARCHAR(20);
ALTER TABLE exp.Material ADD COLUMN AvailableAliquotCount INTEGER NULL;
ALTER TABLE exp.Material ADD COLUMN AvailableAliquotVolume FLOAT NULL;
ALTER TABLE exp.material ADD COLUMN RootMaterialRowId INT;
ALTER TABLE exp.Material ADD CONSTRAINT FK_Material_SampleState
    FOREIGN KEY (SampleState) REFERENCES core.DataStates (RowId);
```

Confirmed live: `query-getQueryDetails.api` on `exp.Materials` returns 42
columns including `RootMaterialRowId`, `AliquotedFromLSID`, `IsAliquot`,
`AliquotCount`, `AliquotVolume`, `AliquotUnit`, `AvailableAliquotCount`,
`StoredAmount`, `Units`, `RawAmount`, `SampleState`, `MaterialExpDate`,
`IsPlated`, `Ancestors`.

Note: there is **no** `rootmateriallsid` column — LabKey replaced the
LSID-based root pointer with `RootMaterialRowId`. A grep across every `exp-*.sql`
returns zero hits.

Name expressions are in `NameGenerator.java`, with substitution values
`AliquotedFrom, DataInputs, MaterialInputs, Inputs, batchRandomId, containerPath,
sampleCount, rootSampleCount, dailySampleCount, weeklySampleCount,
monthlySampleCount, yearlySampleCount, genId, now, randomId, withCounter,
folderPrefix` and more.
`exp.MaterialSource` stores `NameExpression VARCHAR(500)` and
`AliquotNameExpression VARCHAR(200)`.

**Amounts are `DOUBLE PRECISION`/`FLOAT`, not `NUMERIC`.** For OSM this matters:
aliquot splitting on floats accumulates error. OSM uses `NUMERIC` (ADR-0002) and
the bridge converts on publish, accepting the downstream precision loss.

Live: 23 built-in measurement units (`exp.MeasurementUnits`), and exactly three
sample state *types* — `Available`, `Consumed`, `Locked` (`exp.SampleStateType`)
against the eight lifecycle statuses the OSM spec §3 requires.

### Lineage and derivation

Backing tables `exp.Edge(FromObjectId, ToObjectId, RunId)`,
`exp.MaterialAncestors`, `exp.DataAncestors`.
HTTP: `experiment-lineage.api` (`LineageAction`, Read),
`experiment-derive.api` (`DeriveAction`, Insert), `experiment-resolve.api`.

Two negatives worth recording, both verified by grep across the tree:

- **`experiment-saveMaterials.api` does not exist.** No `SaveMaterialsAction`
  anywhere. Use `query-insertRows.api` / `query-import.api` on schema `samples`,
  or `experiment-importSamples.api`.
- **`experiment-deriveSamples` is a view, not an API.** `DeriveSamplesAction`
  extends `FormViewAction`. The programmatic endpoint is `experiment-derive.api`.

### Barcodes — server-side yes, UI gated

The "Unique ID" field type is real on the server:

```java
public static final String STORAGE_UNIQUE_ID_CONCEPT_URI =
    "http://www.labkey.org/types#storageUniqueId";
public static final String STORAGE_UNIQUE_ID_SEQUENCE_PREFIX =
    "org.labkey.api.StorageUniqueId";
```
(`.../api/data/ColumnRenderPropertiesImpl.java:48-49`)

Setting that concept URI on a column auto-enables a DB sequence and hides the
field from insert views (`BaseColumnInfo.java:653-665`). Values are generated
from `DbSequenceManager`.

The **UI** gates it. In the bundled field editor
(`/root/scicore/build/deploy/modules/core/web/gen/domainDesigner.*.js`):

```js
if (type === UNIQUE_ID_TYPE && (isCommunityDistribution() || ...)) return false;
```

**But there is no server-side gate.** Creating a domain property with
`conceptURI: "http://www.labkey.org/types#storageUniqueId"` through
`property-createDomain.api` still produces DbSequence-backed barcode values.
This is a usable capability in CE that the UI simply does not offer.

Barcode lookup exists: `ExperimentService` "from a list of barcodes, find
material lsids", with the Find-by-IDs UI using the `u:` prefix.
A separate non-unique `scannable` flag also exists.

### Audit

The `auditLog` query schema is a real `UserSchema`, so `query-selectRows.api`
and `query-executeSql.api` work against it. 38 providers are registered.
The sample-relevant ones are registered unconditionally, with no edition gate
(`ExperimentModule.java:551-553`):

| Event type | Columns |
| --- | --- |
| `SampleTimelineEvent` | `SampleType, SampleTypeID, SampleName, SampleID, SampleLSID, IsLineageUpdate, InventoryUpdateType, Metadata, UserComment, oldRecordMap, newRecordMap, TransactionID`. Subtypes `INSERT, DELETE, TRUNCATE, MERGE, UPDATE, PUBLISH, RECALL`. `canDeleteOldRows()` returns `false`. |
| `SampleSetAuditEvent` | `SourceLsid, SampleSetName, InsertUpdateChoice, TransactionID, UserComment` |
| `ExperimentAuditEvent` | `ProtocolLsid, RunLsid, ProtocolRun, RunGroup, Message, QCState` |
| `TransactionAuditEvent` | `StartTime, TransactionType, TransactionDetails` — sample rows FK to it |

Sample tables default to `DETAILED` audit behaviour
(`ExpMaterialTableImpl.java:2019`), storing `oldRecordMap`/`newRecordMap`.

Verified live: the `auditLog` schema exposes 37 queries including
`SampleTimelineEvent`, `SampleSetAuditEvent`, `TransactionAuditEvent`,
`QueryUpdateAuditEvent`.

**What CE's audit does not give you**: no hash chaining, no checkpoint, no
tamper evidence. `canDeleteOldRows()` returning `false` prevents routine
purging, but a database administrator can still alter rows undetectably. OSM
§9 requires detection, so CE's trail supplements OSM's and never replaces it
(§16.1, CON-008).

### Search

Apache Lucene 10.5.0 with Tika 3.3.2. Samples **are** indexed
(`ExperimentServiceImpl.indexMaterials()`, document id `material:<rowId>`,
category `material`, custom sample-type columns included).

**Faceted search: no.** Zero occurrences of `facet` in the search module, and no
`lucene-facet` dependency. What exists is category filtering — OR'd `TermQuery`
clauses on a `searchCategories` field. `SearchResult` returns
`totalHits, hits, offset` with **no counts or aggregations**. The sample
categories have `showInAdvancedSearch=false`, so they must be requested
explicitly with `category=material`.

Exactly one search API action: `search-json.api`.

This directly gates OSM §8, which requires facets over type, lineage, storage
and assay thresholds with P95 < 300 ms at 10⁶ samples. CE's search cannot do it.

### Authentication

**Only four providers exist**: `DbLoginAuthenticationProvider` (database
password, and API keys), `LoginAttemptDisableLoginProvider` (lockout), and two
devtools-only test providers.

**No LDAP-auth, CAS, SAML, Duo, TOTP, OAuth or OIDC.** The `OpenLdapSync`
module syncs users and groups only; it contains no `AuthenticationProvider`.

OSM §2 requires OIDC. CE cannot provide it, so OSM provides its own (ADR-0001
makes this OSM's concern anyway).

### API keys

Supported, but **`allowApiKeys` and `allowSessionKeys` both default to `false`**
(`AppPropsImpl.java:546-561`). They must be enabled in site settings.

- Table `core.APIKeys(RowId, CreatedBy, Created, Crypt UNIQUE, Expiration,
  Description, LastUsed)`, plus `RestrictionRole` added in `core-26.006-26.007`.
  Only the SHA-256 crypt is stored.
- Keys are 64-char lowercase hex from `GUID.makeLongHash()`. **There is no
  `apikey|` or `session_` prefix** in this build; `apikey` is the header name
  and the basic-auth username, not a value prefix.
- Transport order: `apikey:` header → `Authorization: Bearer` → basic auth with
  username `apikey` → deprecated cookie → query parameter.
- Creation: `security-createApiKey.api`, returns `{"apikey": "<hex>"}`.
- **Restriction roles**: a key can be minted with a reduced role, limited to
  `ReaderRole, AuthorRole, EditorWithoutDeleteRole, EditorRole`
  (`SecurityController.java:2305-2310`). This is the least-privilege mechanism
  the bridge should use.

### Row-level security — absent

**There is no row-level security on `exp.material`.** The only permission
override delegates every branch to `Container.hasPermission(...)`
(`ExpMaterialTableImpl.java:1844-1860`): no `SimpleFilter` on `CreatedBy`, no
owner check, no per-row policy lookup. Neither `ExpMaterial` nor `ExpSampleType`
implements `SecurableResource`, so samples cannot carry ACLs at all.

The security model is container + role, with inheritance expressed as the
*absence* of a row in `core.Policies`. 29 roles are live on this server.

What exists beyond container+role:

- **Study dataset-level ACLs** — real, but whole datasets, not rows.
- **PHI column masking — present but not enforced.** The `PHI` enum and
  `PhiColumnBehavior` exist and the call sites are in `FilteredTable`, but no
  module registers a `ComplianceService`, so `DefaultComplianceService`
  passes everything through. **PHI tags survive export and import but mask
  nothing.** This is a trap: tagging a column PHI in CE gives no protection.
- `OwnerRole`, applied ad hoc by wikis, issues and message boards. **Never
  applied to `exp.material`.**

To restrict who sees which samples, the only supported mechanism is container
partitioning plus per-container role assignment.

OSM §2 requires RLS. CE has no framework for it.

### Storage — absent from the platform, but present in `laboratory`

No `inventory` schema, no `inventory-*.sql` dbscripts, confirmed by directory
search and confirmed live (`query-getSchemas.api` returns no `inventory`,
`storage` or `freezer` schema).

However, the **deployed** `laboratory` module (LabDevKit) ships a real
freezer model:

- `laboratory.freezers(rowid, name, canes, boxes, rows, columns, comments,
  container)` — `.../laboratory/resources/schemas/dbscripts/postgresql/laboratory-12.24-12.25.sql:40`
- `laboratory.samples` with `freezerid, location, freezer, cane, box, box_row,
  box_column, quantity, quantity_units, dateremoved, removedby, parentsample`
- `laboratory.inventory`
- Reporting queries `freezer_space_summary.sql`, `freezer_usage_by_box.sql`

**It is a separate schema from `exp.material` and is not integrated with Sample
Types.** It is prior art worth reading, not a foundation to build on: it has no
slot-level exclusion constraint, no reservation TTL, and no atomic move
semantics, all of which OSM §5 requires.

## HTTP API actions that matter

Action naming rule, verified at `SpringActionController.java:1084-1172`:
`@ActionNames` wins, first listed is primary; otherwise strip the `Action`
suffix and lowercase the first character only.

| Action | Purpose | Note |
| --- | --- | --- |
| `login-loginApi.api` | login, returns CSRF | params are `email` and `password` |
| `login-whoAmI.api` | session probe, returns CSRF | the user's scripts use this to bootstrap |
| `security-createApiKey.api` | mint an API key | requires `allowApiKeys` enabled |
| `security-getApiKeyRoles.api` | allowed restriction roles | |
| `core-createContainer.api` | create a project or folder | POST to the **parent** path |
| `project-getContainers.api` | enumerate containers | `@RequiresNoPermission` |
| `property-createDomain.api` | create a domain (list, sample type) | controller lives in the **experiment** module |
| `property-saveDomain.api` / `getDomainDetails.api` / `deleteDomain.api` | domain lifecycle | |
| **`query-import.api`** | bulk file import | **the name is `import`, not `importData`** |
| `query-insertRows.api` / `updateRows.api` / `saveRows.api` | row CRUD | |
| `query-selectRows.api` (alias `getQuery.api`) | read | `@CSRF(NONE)` |
| `query-executeSql.api` | LabKey SQL | `@CSRF(NONE)` |
| `experiment-lineage.api` | lineage graph | |
| `experiment-derive.api` | programmatic derivation | |
| `experiment-importSamples.api` | sample import | |
| `assay-importRun.api` | assay run upload | |
| `search-json.api` | the only search API | |
| `audit-getDetailedAuditChanges.api` | audit detail | |
| `wiki-saveWiki.api` | wiki content | |

There is **no `module-` HTTP controller**. File-based module views resolve as
`<modulename>-<viewname>.view`; file-based queries are reached through the
ordinary `query-*` API.

## File-based module layout

`ModuleLoader` reads **`<moduleDir>/config/module.properties`**
(`ModuleLoader.java:1238`), instantiating `SimpleModule` when `ModuleClass` is
absent.

```
<module>/
  config/module.properties        <- REQUIRED, and must be under config/
  queries/<schema>/<Query>.sql
  queries/<schema>/<Query>.query.xml
  queries/<schema>/<Query>/<View>.qview.xml
  views/<name>.html  +  <name>.view.xml  +  <name>.webpart.xml
  web/<module>/...
  schemas/<schema>.xml, schemas/dbscripts/{postgresql,sqlserver}/*.sql
  reports/ scripts/ folderTypes/ domain-templates/ assay/ olap/
```

**A real defect on this server**: `scicoreBrand`'s `module.properties` sits at
the module root rather than under `config/`, so `ModuleLoader` ignores it and
the module loads as a `SimpleModule` named after its directory. Correct
placement is `scicoreBrand/config/module.properties`. Recorded because it is
prior art the project should not copy.

## Live server state

| Fact | Value |
| --- | --- |
| Base URL | `https://127.0.0.1:8443`, self-signed |
| Login | `POST /login-loginApi.api` with `email` + `password`, returns `CSRF` |
| CSRF | the `X-LABKEY-CSRF` cookie value, sent as the same-named header |
| Schemas in `/home` | announcement, assay, auditLog, cluster, core, exp, exp.data, exp.materials, flow, issues, ListManager, lists, ms2, pipeline, plate, protein, query, samples, study, targetedms, targetedmslists, wiki |
| Roles | 29, including `SampleTypeDesignerRole` and `DataClassDesignerRole` |
| Sample state types | 3: Available, Consumed, Locked |
| Measurement units | 23 |
| Containers | `/home`, `/Shared`, `/Tutorials`, `/UCI-Labs`, `/SleepDrive-Lab`, `/_mothership` |

`/SleepDrive-Lab` and its subfolders belong to other work and must not be
touched by this project.
