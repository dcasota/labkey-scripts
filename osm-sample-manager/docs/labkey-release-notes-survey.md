# LabKey release-notes survey — sample management, 2007 to 2026

Raw harvest. Every claim on this page comes from a LabKey release-notes page,
cited by URL. Nothing here is inferred; where a page could not be fetched, that
is stated rather than filled in.

This is a **`doc`-grade source** by the project's own evidence hierarchy
(`standards/general/verification.md`): documentation is the weakest evidence,
because documentation and implementation diverge. `docs/labkey-ce-ground-truth.md`
records several cases where they do. Nothing here should be treated as verified
LabKey CE behaviour until it is checked against `/root/scicore` or the running
server. What this survey *is* good for is the opposite direction: it is
authoritative about **what LabKey chose to build, when, and behind which
paywall** — which is the shape of the problem OSM is solving.

**LabKey ships these. It does not follow that OSM should build them.** The
"OSM disposition" column on each cross-cutting finding says which is which, and
§7 lists everything flagged as questionable scope.

## Method

1. The release inventory comes from the list that
   [Previous Releases](https://www.labkey.org/Documentation/wiki-page.view?name=prevreleases)
   itself queries. That page builds its table client-side from
   `lists.previousReleases` in `/Documentation`, and derives each release-notes
   link as
   `https://www.labkey.org/Documentation/Archive/{major}.{minor}/wiki-page.view?name=releaseNotes{major}{minor}`.
   The inventory was therefore read from the same source the page uses:
   `GET /Documentation/query-selectRows.api?schemaName=lists&query.queryName=previousReleases&query.maxRows=-1&query.sort=-releaseDate`
   → 59 rows, 59 distinct `major.minor` versions. URLs were derived from that
   list, not guessed.
2. Two further releases (26.7, 26.11) are current rather than archived and are
   linked from the same page's navigation as
   `/Documentation/wiki-page.view?name=releasenotes267` and `…2611`.
   **Total enumerated: 61.**
3. Each page was fetched over HTTPS and its `div.labkey-wiki` body converted to
   text. The premium marker LabKey uses is the star icon
   `<span class="fa fa-star-o"></span>`; it is preserved below as **[P]**. Its
   own legend, printed at the foot of most pages, reads: *"The ★ symbol
   indicates a feature available in a Premium Edition of LabKey Server."*
   From 22.11 the legend widens to *"…a Premium Edition of LabKey Server,
   Sample Manager, or Biologics LIMS."*

## Coverage

| | Count |
| --- | --- |
| Releases enumerated | 61 |
| Release-notes pages fetched (HTTP 200, non-empty body) | 60 |
| Releases with no release-notes page | 1 (2.0) |
| Fetch failures (network, rate limit, block) | 0 |

The site did not rate-limit or block the harvest.

Three URL patterns are in use, and the pattern the Previous Releases page
advertises is only correct from 10.1 onward:

| Releases | Pattern |
| --- | --- |
| 2.1 – 2.3 | `…/Documentation/Archive/{v}/wiki-page.view?name=whatsNew` |
| 8.1 – 9.3 | `…/Documentation/Archive/{v}/wiki-page.view?name=whatsnew{MM}` |
| 10.1 – 26.3 | `…/Documentation/Archive/{v}/wiki-page.view?name=releaseNotes{MM}` |
| 26.7, 26.11 | `…/Documentation/wiki-page.view?name=releasenotes{MM}` |

The advertised `releaseNotes{MM}` URL **404s for every release before 10.1**
(ten releases: 2.0, 2.1, 2.2, 2.3, 8.1, 8.2, 8.3, 9.1, 9.2, 9.3). Those pages
exist under the alternate names above and were recovered. For **2.0 the page
does not exist at all**: `Archive/2.0/project-begin.view` returns 200 and its
navigation contains no release-notes, what's-new or changes page. That is a gap
in LabKey's archive, not a failure of this harvest.

### Dates

The `previousReleases` list carries a `releaseDate`, but for older entries it is
the date the *archive* was last built, not the date the version shipped — 23.3
is listed as 2024-01-12, and 21.3, 21.7, 21.11 and 22.3 are all listed within
four days of each other in March 2022/2023. **Where the release-notes page
states its own month, that is used below and is authoritative.** Pages before
19.2 state no date; those entries say so.

## 1. Coverage table

| Version | Page date | Status | URL |
| --- | --- | --- | --- |
| 2.0 | not stated on page | **no page** | — |
| 2.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/2.1/wiki-page.view?name=whatsNew> |
| 2.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/2.2/wiki-page.view?name=whatsNew> |
| 2.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/2.3/wiki-page.view?name=whatsNew> |
| 8.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/8.1/wiki-page.view?name=whatsnew81> |
| 8.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/8.2/wiki-page.view?name=whatsnew82> |
| 8.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/8.3/wiki-page.view?name=whatsnew83> |
| 9.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/9.1/wiki-page.view?name=whatsnew91> |
| 9.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/9.2/wiki-page.view?name=whatsnew92> |
| 9.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/9.3/wiki-page.view?name=whatsnew93> |
| 10.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/10.1/wiki-page.view?name=releaseNotes101> |
| 10.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/10.2/wiki-page.view?name=releaseNotes102> |
| 10.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/10.3/wiki-page.view?name=releaseNotes103> |
| 11.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/11.1/wiki-page.view?name=releaseNotes111> |
| 11.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/11.2/wiki-page.view?name=releaseNotes112> |
| 11.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/11.3/wiki-page.view?name=releaseNotes113> |
| 12.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/12.1/wiki-page.view?name=releaseNotes121> |
| 12.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/12.2/wiki-page.view?name=releaseNotes122> |
| 12.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/12.3/wiki-page.view?name=releaseNotes123> |
| 13.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/13.1/wiki-page.view?name=releaseNotes131> |
| 13.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/13.2/wiki-page.view?name=releaseNotes132> |
| 13.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/13.3/wiki-page.view?name=releaseNotes133> |
| 14.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/14.1/wiki-page.view?name=releaseNotes141> |
| 14.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/14.2/wiki-page.view?name=releaseNotes142> |
| 14.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/14.3/wiki-page.view?name=releaseNotes143> |
| 15.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/15.1/wiki-page.view?name=releaseNotes151> |
| 15.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/15.2/wiki-page.view?name=releaseNotes152> |
| 15.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/15.3/wiki-page.view?name=releaseNotes153> |
| 16.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/16.1/wiki-page.view?name=releaseNotes161> |
| 16.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/16.2/wiki-page.view?name=releaseNotes162> |
| 16.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/16.3/wiki-page.view?name=releaseNotes163> |
| 17.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/17.1/wiki-page.view?name=releaseNotes171> |
| 17.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/17.2/wiki-page.view?name=releaseNotes172> |
| 17.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/17.3/wiki-page.view?name=releaseNotes173> |
| 18.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/18.1/wiki-page.view?name=releaseNotes181> |
| 18.2 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/18.2/wiki-page.view?name=releaseNotes182> |
| 18.3 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/18.3/wiki-page.view?name=releaseNotes183> |
| 19.1 | not stated on page | 200 | <https://www.labkey.org/Documentation/Archive/19.1/wiki-page.view?name=releaseNotes191> |
| 19.2 | July 2019 | 200 | <https://www.labkey.org/Documentation/Archive/19.2/wiki-page.view?name=releaseNotes192> |
| 19.3 | November 2019 | 200 | <https://www.labkey.org/Documentation/Archive/19.3/wiki-page.view?name=releaseNotes193> |
| 20.3 | March 2020 | 200 | <https://www.labkey.org/Documentation/Archive/20.3/wiki-page.view?name=releaseNotes203> |
| 20.7 | July 2020 | 200 | <https://www.labkey.org/Documentation/Archive/20.7/wiki-page.view?name=releaseNotes207> |
| 20.11 | November 2020 | 200 | <https://www.labkey.org/Documentation/Archive/20.11/wiki-page.view?name=releaseNotes2011> |
| 21.3 | March 2021 | 200 | <https://www.labkey.org/Documentation/Archive/21.3/wiki-page.view?name=releaseNotes213> |
| 21.7 | July 2021 | 200 | <https://www.labkey.org/Documentation/Archive/21.7/wiki-page.view?name=releaseNotes217> |
| 21.11 | November 2021 | 200 | <https://www.labkey.org/Documentation/Archive/21.11/wiki-page.view?name=releaseNotes2111> |
| 22.3 | March 2022 | 200 | <https://www.labkey.org/Documentation/Archive/22.3/wiki-page.view?name=releaseNotes223> |
| 22.7 | July 2022 | 200 | <https://www.labkey.org/Documentation/Archive/22.7/wiki-page.view?name=releaseNotes227> |
| 22.11 | November 2022 | 200 | <https://www.labkey.org/Documentation/Archive/22.11/wiki-page.view?name=releaseNotes2211> |
| 23.3 | March 2023 | 200 | <https://www.labkey.org/Documentation/Archive/23.3/wiki-page.view?name=releaseNotes233> |
| 23.7 | July 2023 | 200 | <https://www.labkey.org/Documentation/Archive/23.7/wiki-page.view?name=releaseNotes237> |
| 23.11 | November 2023 | 200 | <https://www.labkey.org/Documentation/Archive/23.11/wiki-page.view?name=releaseNotes2311> |
| 24.3 | March 2024 | 200 | <https://www.labkey.org/Documentation/Archive/24.3/wiki-page.view?name=releaseNotes243> |
| 24.7 | July 2024 | 200 | <https://www.labkey.org/Documentation/Archive/24.7/wiki-page.view?name=releaseNotes247> |
| 24.11 | November 2024 | 200 | <https://www.labkey.org/Documentation/Archive/24.11/wiki-page.view?name=releaseNotes2411> |
| 25.3 | March 2025 | 200 | <https://www.labkey.org/Documentation/Archive/25.3/wiki-page.view?name=releaseNotes253> |
| 25.7 | July 2025 | 200 | <https://www.labkey.org/Documentation/Archive/25.7/wiki-page.view?name=releaseNotes257> |
| 25.11 | November 2025 | 200 | <https://www.labkey.org/Documentation/Archive/25.11/wiki-page.view?name=releaseNotes2511> |
| 26.3 | March 2026 | 200 | <https://www.labkey.org/Documentation/Archive/26.3/wiki-page.view?name=releaseNotes263> |
| 26.7 | July 2026 | 200 | <https://www.labkey.org/Documentation/wiki-page.view?name=releasenotes267> |
| 26.11 | in development | 200 | <https://www.labkey.org/Documentation/wiki-page.view?name=releasenotes2611> |

## 2. Era I — the Specimen Repository, 2.0 to 19.2

For its first thirteen years LabKey's answer to "where is this tube" was the
**Specimen Repository**, part of the `study` module: vials, primary specimens,
draw sites, requests and request notifications. It is *not* a freezer map — it
tracks custody and requests over a specimen archive imported from an external
system, not a physical hierarchy of racks and boxes. It matters here for one
reason, recorded in §2.20 below: **LabKey removed it from Community Edition in
21.3**, so the historical prior art is not available to a CE user today.

Only sample-management-relevant items are listed. Assay, proteomics, flow,
Panorama and visualisation items are omitted throughout this document.

### 2.0
No release-notes page exists. `Archive/2.0/project-begin.view` returns 200 and
links no such page. Nothing harvested.

### 2.1
<https://www.labkey.org/Documentation/Archive/2.1/wiki-page.view?name=whatsNew> — date not stated.
Nothing in the sample/specimen domain beyond a passing mention of specimen views.

### 2.2
<https://www.labkey.org/Documentation/Archive/2.2/wiki-page.view?name=whatsNew> — date not stated.
- **First storage-location fields anywhere in LabKey**: *"LabKey has added five
  additional storage location fields and a flag for determining specimen
  availability."* Flat fields on a specimen, not a hierarchy.

### 2.3
<https://www.labkey.org/Documentation/Archive/2.3/wiki-page.view?name=whatsNew> — date not stated.
- **Sample sets and derivation first appear**: *"Enhanced usability of sample
  sets, plus the added capability to derive samples from other samples and to
  describe their properties."*
- **Derived-sample views**: *"Views that display all derived samples from a given
  sample, and indicate what runs use it."* This is the ancestor of today's
  lineage tab.
- Specimen-to-assay mapping via a user-defined cross-reference list.

### 8.1
<https://www.labkey.org/Documentation/Archive/8.1/wiki-page.view?name=whatsnew81> — date not stated.
- Pre-prepared specimen reports (summaries by type and timepoint, requested vials).

### 8.2
<https://www.labkey.org/Documentation/Archive/8.2/wiki-page.view?name=whatsnew82> — date not stated.
Nothing sample-relevant.

### 8.3
<https://www.labkey.org/Documentation/Archive/8.3/wiki-page.view?name=whatsnew83> — date not stated.
- **Specimen request notifications** become configurable (fixed sender address or
  the requesting user).
- **Repository auto-selection** on a by-specimen request.
- **Specimen and vial comments**, preserved across re-import.
- **Per-vial volume change over time** allowed on import.
- A named vial view (`SpecimenEmail`) drives the vial list in request emails.
- User deactivation retains authorship *"for display in the audit log"*.
- *"All actions of impersonators are now logged."*

### 9.1
<https://www.labkey.org/Documentation/Archive/9.1/wiki-page.view?name=whatsnew91> — date not stated.
- **Auto-derivation on sample-set import**: a parent column creates derivation
  history automatically at import time. The direct ancestor of today's
  `MaterialInputs/` import aliases.
- **Specimen "shopping cart"** — search once, then add vials individually or in
  bulk to a request.
- **Specimen comments are audited.**

### 9.2
<https://www.labkey.org/Documentation/Archive/9.2/wiki-page.view?name=whatsnew92> — date not stated.
- **Role-based specimen security**: four new roles including *Specimen
  Coordinator* and *Specimen Requester*, so a requester need not be a folder
  admin. The first appearance of the "narrow operational role" pattern OSM
  needs for Technician and Storage admin.
- **Conflict detection over vial events**, including the case that matters most
  to a freezer map: *"Vial events that indicate a single vial is simultaneously
  at multiple locations are flagged."* LabKey detects and flags this after the
  fact; it does not prevent it. OSM §5 prevents it with a database constraint
  (ADR-0004).
- Manual flag/unflag of a QC problem, preserved across re-import.
- Sibling-vial availability columns (available, locked in requests, at
  repository, expected).

### 9.3
<https://www.labkey.org/Documentation/Archive/9.3/wiki-page.view?name=whatsnew93> — date not stated.
- Specimen repository settings can be configured without an existing archive.

### 10.1
<https://www.labkey.org/Documentation/Archive/10.1/wiki-page.view?name=releaseNotes101> — date not stated.
- **Configurable requestability rules**: admin-defined queries decide which vials
  are requestable, each annotated with *why*, with a defined resolution order.
  Evaluated **only at import**: *"changes to the queries will not affect the
  requestability of vials currently stored in the system until the next specimen
  import."* A rule that runs at import and never again is exactly the failure
  mode OSM's server-side status enforcement (PR-012) exists to avoid.
- `ProcessingTechInitial` — the technician who processed a vial.

### 10.2
<https://www.labkey.org/Documentation/Archive/10.2/wiki-page.view?name=releaseNotes102> — date not stated.
- Sample sets gain a full insert/update/delete HTML interface and client-API
  equivalents; sample sets available for all assay data types.
- **`LABKEY.Experiment.saveMaterials()` is deprecated**: *"redundant with the
  improved QueryUpdateService API … Use `LABKEY.Query` instead."* This is the
  documentary confirmation of the ground-truth finding that
  `experiment-saveMaterials.api` does not exist
  (`docs/labkey-ce-ground-truth.md`, and `standards/labkey/http-conventions.md`).
  It was deprecated in 2010.

### 10.3
<https://www.labkey.org/Documentation/Archive/10.3/wiki-page.view?name=releaseNotes103> — date not stated.
- Specimen tracking supports vial merging.

### 11.1
<https://www.labkey.org/Documentation/Archive/11.1/wiki-page.view?name=releaseNotes111> — date not stated.
- Specimen tube type; specimens-per-participant view.

### 11.2
<https://www.labkey.org/Documentation/Archive/11.2/wiki-page.view?name=releaseNotes112> — date not stated.
- **SampleMinded import format supported** (removed again in 25.3, §4).
- Specimen request notification defaults.
- **Auditing configurable per table**: *"Configure auditing for any table."*

### 11.3
<https://www.labkey.org/Documentation/Archive/11.3/wiki-page.view?name=releaseNotes113> — date not stated.
- Improved specimen request email notification options; anonymised specimen
  snapshots; ancillary study from a specimen request.

### 12.1
<https://www.labkey.org/Documentation/Archive/12.1/wiki-page.view?name=releaseNotes121> — date not stated.
Nothing sample-relevant beyond notification wording.

### 12.2
<https://www.labkey.org/Documentation/Archive/12.2/wiki-page.view?name=releaseNotes122> — date not stated.
- **Folder export/import consolidated** into folder archives (folder settings,
  external schema definitions, study archives nested inside folder archives).
  This is the mechanism §16 requires OSM to use instead of `addWebPart`
  (PRO-004).
- Dataset export events, with filter information, appear in the audit log.

### 12.3
<https://www.labkey.org/Documentation/Archive/12.3/wiki-page.view?name=releaseNotes123> — date not stated.
- Vial-list placement in request emails; clinic/draw-site name masking; vial
  grouping hierarchy in the browser.

### 13.1
<https://www.labkey.org/Documentation/Archive/13.1/wiki-page.view?name=releaseNotes131> — date not stated.
Nothing sample-relevant.

### 13.2
<https://www.labkey.org/Documentation/Archive/13.2/wiki-page.view?name=releaseNotes132> — date not stated.
- **Vial aliquoting**: *"Specimen aliquots. Support for vial aliquoting."*
  Aliquots exist in LabKey nine years before they reach Sample Manager (21.7).
- Faceted filtering panel over specimen requests — LabKey's earliest faceted
  browse, and confined to the specimen module.
- Editable specimen records.

### 13.3
<https://www.labkey.org/Documentation/Archive/13.3/wiki-page.view?name=releaseNotes133> — date not stated.
- **Custom aliquots**: *"Manage non-vial specimen types such as tissue blocks."*
- Export of specimen repository and request settings.
- S3 cloud storage integration for large data files.

### 14.1
<https://www.labkey.org/Documentation/Archive/14.1/wiki-page.view?name=releaseNotes141> — date not stated.
- **FreezerPro integration** — LabKey's first freezer capability of any kind, and
  it is an integration with somebody else's freezer system, not a freezer map.
  (Support removed in 25.3, §4.)
- Provisioned specimen tables; admin-customisable specimen fields; **rollup
  fields** storing aggregate and latest values in the specimen tables — the
  ancestor of today's `AliquotCount`/`AvailableAliquotVolume` rollups.
- New roles **See Audit Log Events** and See Email Addresses.

### 14.2
<https://www.labkey.org/Documentation/Archive/14.2/wiki-page.view?name=releaseNotes142> — date not stated.
- FreezerPro import on demand or on a schedule.
- New specimen rollup rules (Combine, LatestNonBlank).
- **PHI activity auditing.**

### 14.3
<https://www.labkey.org/Documentation/Archive/14.3/wiki-page.view?name=releaseNotes143> — date not stated.
Specimen and PHI refinements only.

### 15.1
<https://www.labkey.org/Documentation/Archive/15.1/wiki-page.view?name=releaseNotes151> — date not stated.
- Study, list and folder archives standardise on UTF-8.

### 15.2
<https://www.labkey.org/Documentation/Archive/15.2/wiki-page.view?name=releaseNotes152> — date not stated.
- **File upload for sample sets** (TSV, XLS, XLSX) — the ancestor of CSV bulk
  intake (PR-014).

### 15.3
<https://www.labkey.org/Documentation/Archive/15.3/wiki-page.view?name=releaseNotes153> — date not stated.
Nothing sample-relevant.

### 16.1
<https://www.labkey.org/Documentation/Archive/16.1/wiki-page.view?name=releaseNotes161> — date not stated.
- FreezerPro setup/mapping UI. Explicitly *"Available in LabKey Server
  Professional, Professional Plus, and Enterprise Editions"* — the earliest
  edition-gating language found in this survey for a storage-adjacent feature.

### 16.2
<https://www.labkey.org/Documentation/Archive/16.2/wiki-page.view?name=releaseNotes162> — date not stated.
- **Sample parentage/lineage as a first-class concept**: *"A new way to indicate
  parentage in Sample Sets has been added. The previous way to indicate lineage,
  the 'Parents' column, is still present, but should be considered deprecated."*
- Notifications inbox (experimental).

### 16.3
<https://www.labkey.org/Documentation/Archive/16.3/wiki-page.view?name=releaseNotes163> — date not stated.
- Sample sets can resolve samples across containers.
- Folder-archive import can select a subset of objects and apply the template to
  several folders at once. (Both deprecated in 24.11 and **removed in 25.11**,
  §4 — a caution for any OSM publish path that leans on selective import.)
- **API session key** — run client API code without storing credentials on the
  client. The forerunner of API keys (ADR-0008 territory).

### 17.1
<https://www.labkey.org/Documentation/Archive/17.1/wiki-page.view?name=releaseNotes171> — date not stated.
- **Name expressions arrive**: *"Sample Ids — New flexible options for naming
  samples in sample sets. Build a unique id for each sample using fields from
  the current row, random numbers, iterating integers, etc."* This is the
  feature PR-010 models.
- *"Notify administrators if audit processing fails."*
- Documentation only: a *"Tutorial: Electronic Lab Notebook"* showing how to
  assemble notebook-like behaviour out of ordinary LabKey parts. There is no ELN
  product at this point.
- FISMA compliance enhancements, premium editions.

### 17.2
<https://www.labkey.org/Documentation/Archive/17.2/wiki-page.view?name=releaseNotes172> — date not stated.
- **Media, recipes and ingredients** enter Biologics: *"Media Batches — Users can
  create media batches using recipes and ingredients already entered into the
  repository."* Vendor-supplied mixtures with unknown ingredients supported.
- New roles Shared View Editor and **Application Administrator** (*"more
  permission than a project administrator but less than a site administrator …
  cannot set or change file roots, authentication settings, or full-text search
  configuration"*).

### 17.3
<https://www.labkey.org/Documentation/Archive/17.3/wiki-page.view?name=releaseNotes173> — date not stated.
- **[P] Electronic Signatures — first appearance**: *"Sign a data grid snapshot,
  and specify a reason for signing. Signed documents are listed in the Signed
  Snapshots table."* Note what is signed: a **grid snapshot**, with a reason.
  There is no content hash and no re-authentication in this description.
- **PHI column levels — first appearance**: *"Mark individual columns with a PHI
  level (Not PHI, Limited PHI, Full PHI, or Restricted). Exclude columns of a
  particular level and higher during study publishing and folder export."*
  Note the scope: exclusion **at publish and export**, not masking at read.
- *"Write Audit Logs to File System — Some or all of the audit log can be
  written to the filesystem."*
- LabKey Server as a CAS identity provider.

### 18.1
<https://www.labkey.org/Documentation/Archive/18.1/wiki-page.view?name=releaseNotes181> — date not stated.
- **[P] PHI data handling and logging expanded** to study datasets and lists.
- **[P] Dataset PHI logging**: optionally log the SQL queried, the participant
  ids accessed, and the set of PHI columns accessed.
- **[P] Compliance: admins are no longer automatically granted PHI access** —
  *"To comply with logging and audit requirements, administrators are no longer
  automatically granted access to Protected Health Information."* An
  administrator is not a data subject's proxy. Worth mirroring in OSM's role
  model (PR-006).
- CE: **per-property domain change auditing** (*"Per-property changes to any
  domain (list, dataset, etc.) are recorded in the audit log"*) and
  **impersonation auditing** (start and stop).

### 18.2
<https://www.labkey.org/Documentation/Archive/18.2/wiki-page.view?name=releaseNotes182> — date not stated.
- **[P] Bulk import for media** — ingredients for recipes or batches.
- **Report of columns and their PHI levels**, for administrators.
- Adjudication events audited.

### 18.3
<https://www.labkey.org/Documentation/Archive/18.3/wiki-page.view?name=releaseNotes183> — date not stated.
- **[P] Lineage grid** — sample lineage in grid form (Biologics).
- **[P] Experiment framework** — manage experiments, their samples and their
  assay data; add and remove samples from an experiment. This is the direct
  ancestor of workflow **jobs**, and it was removed from the UI in 21.7 with the
  instruction *"Use workflow jobs instead."*
- Premium resources: *Configuring LabKey for GDPR Compliance*, *Sample
  Management Demo*.

### 19.1
<https://www.labkey.org/Documentation/Archive/19.1/wiki-page.view?name=releaseNotes191> — date not stated.
- Sample-set creation/import streamlined; large-import performance.
- **Removed**: the *"active sample set"* feature and *"unique suffixes for
  sample sets"*.
- 19.1.1: **sample sets included in `.folder.zip` archives** on export/import.

### 19.2
<https://www.labkey.org/Documentation/Archive/19.2/wiki-page.view?name=releaseNotes192> — **July 2019**.
- **Parent column aliases**: *"When importing sample data, indicate the column or
  columns that contain parentage information."* (PR-011/PR-014 territory.)
- **Unique value counters in name expressions**: *"Generate a sequential ID based
  on values in other columns in a sample set, such as a series per lot."* This
  is `:withCounter`, and it is the hardest part of PR-010 to get right under
  concurrency.
- Failed logins record the client IP address.

## 3. Era II — Sample Manager, 19.3 to 24.7

Sample Manager is announced in 19.3 and is a **premium product from the first
day it exists**. Every item in this era marked [P] carries LabKey's own star
marker on the release-notes page. Items *not* marked appear in the Sample
Manager section of a release-notes page and are therefore Sample Manager
features regardless — the star is used inconsistently inside product sections,
because the whole section is already premium. Where LabKey names an edition
explicitly, the edition is quoted.

### 19.3
<https://www.labkey.org/Documentation/Archive/19.3/wiki-page.view?name=releaseNotes193> — **November 2019**.
- **Sample Manager announced**: *"Sample Manager is ready for preview. Designed
  in collaboration with laboratory researchers, LabKey Sample Manager is built
  to help researchers track and link together samples, sample lineage,
  associated experimental data, and workflows. Request a demo."*
  Note *"Request a demo"* — commercial from the announcement.
- CE: trigger-script support on sample-set import; append-or-merge import
  option; **samples can no longer be deleted if they are inputs to a derivation
  or assay run** (referential protection OSM needs in PR-013).
- Biologics: lineage tab with graphical and grid views.

### 20.3
<https://www.labkey.org/Documentation/Archive/20.3/wiki-page.view?name=releaseNotes203> — **March 2020**.
- **[P]** *"LabKey Sample Manager is now available with every Premium Edition,
  offering easy tracking of laboratory workflows, sample lineage, and
  experimental data."* The paywall is stated in the release notes themselves.

### 20.7
<https://www.labkey.org/Documentation/Archive/20.7/wiki-page.view?name=releaseNotes207> — **July 2020**.
- **[P] Sample Sources** — *"Track the sources and provenance of your samples,
  such as organism or lab of origin."* (OSM `Source`, FR-014.)
- **[P] Sample Timeline** — *"Capture all events related to a specific sample in
  a convenient graphical timeline for auditing purposes and chain of custody
  tracking. Timeline information can be exported to Excel, TSV, and CSV
  formats."* This is FR-026 / PR-015, and LabKey's phrase *"chain of custody"*
  is the same claim OSM §1 makes.
- **[P] Search enhancements** — filter and refine search results by type, user,
  date.
- CE: **terminology change, "Sample Set" → "Sample Type"**, *"There are no
  functionality changes implied by this name change."*
- CE: **sample timeline events are added to the audit log** — *"Sample timeline
  events, such as editing a sample or adding it to a job, are added to the audit
  log."* The *events* are in CE; the timeline *view* is premium.
- CE: lineage editing — parents updated individually or deleted via merge on
  import.

### 20.11
<https://www.labkey.org/Documentation/Archive/20.11/wiki-page.view?name=releaseNotes2011> — **November 2020**.
- **[P] BarTender integration** — *"Print BarTender labels for samples in Sample
  Manager."* This is LabKey's *only* label-printing story, and it is an
  integration with a commercial Windows product. **No ZPL, no Zebra, no direct
  printer protocol appears anywhere in 60 releases of notes.** OSM §15's ZPL
  requirement has no prior art here.
- **[P] Label colours** for sample types.
- **Announcement of the specimen removal**: *"Beginning with release 21.3 (March
  2021), Specimen tracking functionality will be removed from standard
  distributions of LabKey Server. Instead, we recommend using Sample Types and
  Sample Manager for managing specimen information. Clients who rely on the
  existing repository will still receive it with their subscriptions."*

### 21.3
<https://www.labkey.org/Documentation/Archive/21.3/wiki-page.view?name=releaseNotes213> — **March 2021**.

The single most important release for this project.

- **[P] Freezer management arrives in Sample Manager.** Verbatim:
  - *"Match digital storage to physical storage in your lab."* (FR-003, the 1:1
    correspondence requirement.)
  - *"Easily store and locate samples."*
  - *"Track location history and chain of custody."*
  - *"Check samples in and out of storage, record amount used, and increment
    freeze/thaw counts."* (FR-029. Note **freeze/thaw counting**, which the OSM
    specification does not mention at all — see §7, questionable scope.)
  - *"Easily migrate from another system by importing sample data simultaneously
    with location data."*
- **[P] Derive children samples from one or more parent samples**; **[P] pool
  multiple samples into a set of new samples** (FR-025, PR-013).
- **[P]** Background sample imports with in-app notification on completion, and
  removal of previous import size limits.
- **Specimen Repository removed from Community Edition.** Verbatim, twice:
  *"Specimen functionality has been removed from the study module. If you are
  using a Premium Edition and need to continue using this functionality, contact
  your Account Manager to obtain the specimen module. **Do not upgrade a
  Community Edition if you want to continue using specimen as part of study.**"*
  and *"Specimen Repository functionality has been removed from all standard
  distributions (Community, Starter, Professional, and Enterprise). We will
  continue to provide and support this functionality only for Premium Edition
  clients who currently use it."*
- Also removed from CE in this release: Microsoft SQL Server and all
  non-PostgreSQL external data sources (BigIron module moves to premium).
- CE: Data Classes can be added to an exported folder archive.

### 21.7
<https://www.labkey.org/Documentation/Archive/21.7/wiki-page.view?name=releaseNotes217> — **July 2021**.
- **Barcode / UniqueID field type**: *"A new field type, 'UniqueID', generates
  system-wide unique values that can be encoded as Barcodes when samples are
  added to a Sample Type or when the barcode field is added to an existing
  sample type."* On the LabKey Server side the same item is marked **[P]**:
  *"Barcode Field — A new field type generates unique id values for Samples."*
  This is the feature `docs/labkey-ce-ground-truth.md` proves is **blocked only
  in JavaScript** — the server accepts
  `conceptURI: http://www.labkey.org/types#storageUniqueId` in CE.
- **Aliquots reach Sample Manager**: *"Create aliquots of samples singly or in
  bulk."* (FR-015, FR-025.)
- **Picklists**: *"Create and manage picklists of samples to simplify operations
  on groups of samples."* (FR-027, PR-028.)
- **Move storage units**: *"Track movement of storage units within a freezer, or
  to another freezer."* The closest LabKey equivalent to OSM's atomic box move
  (FR-030) — and LabKey documents it as a tracked movement, not as an atomic
  batch with conflict semantics.
- **Clone freezer**: *"Create a new freezer definition by copying an existing."*
  Not in the OSM specification; see §7.
- Workflow: *"On the main menu, 'My Assigned Work' has been renamed 'My
  Queue'."* (FR-034.)
- File and attachment fields on samples and sources.
- **Biologics gains the ELN**: *"Electronic Lab Notebooks have been added to
  LabKey Biologics. Link directly to data in the registry and collaboratively
  author/review notebooks."* Workflow with job templates and personalised task
  queues also lands in Biologics here.
- Biologics: *"The 'Experiment' menu has been removed from the UI. Use workflow
  jobs instead."*
- **[P] Expanded PHI**: *"Assign PHI levels to fields in SampleTypes and
  DataClasses."* Relevant to PRO-003 — PHI tags now exist on the very tables the
  OSM bridge writes to.
- **[P] Project locking** — *"Administrators can manually lock a project, making
  it inaccessible to non-administrators."*
- **[P] Project review workflow** — *"Administrators can enforce regular review
  of project access permissions."* Access recertification. Not in the OSM
  specification; see §7.
- CE: study/sample integration — link samples to studies, tag participant and
  timepoint fields on sample types (CON-009 territory).
- **Specialty Assays removed from Community Edition**: *"Users will need to
  subscribe to a Premium Edition to use ELISA, ELISpot, NAb, Luminex, Flow, and
  other specialized assays. The Community Edition will continue to support the
  customizable Standard Assay."*

### 21.11
<https://www.labkey.org/Documentation/Archive/21.11/wiki-page.view?name=releaseNotes2111> — **November 2021**.
- **Sample status arrives**: *"Manage sample status, including but not limited
  to: available, consumed, locked."* And the schema note: *"An additional
  reserved field 'SampleState' has been added to support this feature. If your
  existing Sample Types use user defined fields for recording sample status, you
  will want to migrate to using the new method."*
  This is the feature `docs/labkey-ce-ground-truth.md` proves **enforces
  nothing** in CE (`isOperationPermitted()` returns `true` unconditionally).
  The release notes say "manage status"; they never claim status is enforced.
- **Aliquot naming patterns** customisable, in Sample Manager and Biologics.
- **`:withCounter`** field-based counters in sample names.
- **Lineage lookups in naming patterns** — a name can reference a parent's field.
- **Project name prefix**: *"Assign a prefix to be included in the names of all
  Samples and Sources created in a given project."*
- **Prevent user-supplied IDs**: *"Prevent users from creating their own
  IDs/Names in order to maintain consistency using defined naming patterns."*
  A real requirement OSM's specification does not state; see §7.
- **Freezer location hierarchy**: *"Record the physical location of freezers you
  manage, making it easier to find samples across distributed sites."* — with
  the striking caveat *"Contact us to have your Freezer Location hierarchy
  configured."* In 21.11 the top of the storage hierarchy was **not
  self-service**. OSM's FR-028 requires all five levels to be user-manageable.
- **Aliquot rollups at the parent**: *"See aggregate volume and count of aliquots
  and sub-aliquots."* Confirms **sub-aliquots** are supported (PR-013).
- **Find samples using barcodes or sample IDs.**
- Bulk edit of sources and parents; view all samples and aliquots from a source.
- **Lineage graph depth raised from 3 to 5 generations.**
- Workflow: markdown, multi-threaded comments on job tasks; redesigned job and
  task pages; improved template management.
- Assay designs can be **archived** — hidden from data entry while historic data
  stays viewable. (A softer alternative to deletion that OSM does not specify;
  see §7.)
- CE upgrade note: `core.qcstate` renamed `core.datastates`.

### 22.3
<https://www.labkey.org/Documentation/Archive/22.3/wiki-page.view?name=releaseNotes223> — **March 2022**.
- **Sample Finder arrives**: *"Find samples based on source and parent
  properties, giving users the flexibility to locate samples based on
  relationships and lineage details."* (FR-006, FR-039, PR-027.) Note the
  initial scope: **parent and source properties only**. Sample's own properties
  do not arrive until 23.7, and assay-result filters until 22.11 — see §6.
- **Storage roles split out**: *"New Storage Editor and Storage Designer roles,
  allowing admins to assign different users the ability to manage freezer
  storage and manage sample and assay definitions."* With the consequence spelled
  out: *"users with the 'Administrator' and 'Editor' role no longer have the
  ability to edit storage information unless they are granted one of these new
  storage roles."* Directly relevant to FR-047's Storage/Workflow admin.
- **Freezer capacity shown while navigating** the hierarchy to store or move.
- Storage labels and descriptions; **add storage units in bulk**.
- **Status coupling**: *"When a sample is marked as 'Consumed', the user will be
  prompted to also change its storage status to 'Discarded' (and vice versa)."*
  A *prompt*, not a rule. OSM §3 makes this a transition.
- Sample Type Insights panel (storage, status rollups per type).
- **User-defined barcodes**: text or integer fields declared as barcodes and
  scanned when searching by barcode — distinct from the generated UniqueID.
- Naming patterns **validated at definition time**, with example names shown.
  (PR-010's acceptance criterion: *"An invalid pattern is rejected at definition
  time with the position of the error."*)
- **Digit-only sample names disambiguated** against rowIds: *"such ambiguities
  will be resolved by assuming that a sample name has been provided."* A real
  hazard for OSM's barcode and ID resolution (PR-019).
- Comment when updating storage amounts or freeze/thaw counts.
- Workflow tasks involving assays prepopulate the sample grid.
- **[P]** *"Sample status types and values are exported and imported with folder
  archives, when the sampleManagement module is present."* The `sampleManagement`
  module is premium, so a CE folder archive round-trip **loses status
  definitions**. Direct consequence for the publish bridge (PR-031).
- Biologics: **freezer management extended to Biologics**; picklists;
  notebook entry locking (*"Users are notified if someone else is already
  editing a notebook entry and prevented from accidentally overwriting their
  work"*); notebook find/filter dashboard.
- CE: **Text Choice** data type; **Project Creator** role; Content-Security-Policy
  filter; **JSESSIONID no longer accepted in place of a CSRF token**
  (`standards/labkey/http-conventions.md`).
- CE: **study archives no longer importable — folder archives only.**

### 22.7
<https://www.labkey.org/Documentation/Archive/22.7/wiki-page.view?name=releaseNotes227> — **July 2022**.
- **The ELN reaches Sample Manager, and its edition is named**: *"Our
  user-friendly ELN (Electronic Lab Notebook) is designed to help scientists
  efficiently document their experiments and collaborate. … **Available in the
  Professional Edition of Sample Manager and with the Enterprise Edition of
  LabKey Server.**"* (FR-005; PR-024 through PR-026.)
- **Picklists surfaced** for sharable sample lists, shipping manifests and daily
  work lists.
- **Saved Sample Finder searches** — *"create standard sample reports by saving
  your Sample Finder searches to access later."* (Not in the OSM specification;
  see §7.)
- **Samples can be renamed**: *"all changes are recorded in the audit log and
  sample ID uniqueness is still required."*
- **Sort and filter on lineage metadata** — ancestor (source and parent) details
  brought into sample grids. (PR-027.)
- **Multi-tabbed export** of sample types to one spreadsheet, for manifests.
- Custom grid views per user, admin-set defaults, **including custom views of
  the audit log**.
- Sample Type and Source Type **renaming**.
- Multiple filter expressions per column in Sample Finder.
- Biologics: **signed, human-readable ELN snapshot export**; ELN checkboxes;
  images stored as attachments; **freezers shared across subfolders**; full-text
  search across bioregistry entities, samples and notebooks.
- CE: sample and data-class **rename**; commas allowed in names; ancestor
  metadata in grids.

### 22.11
<https://www.labkey.org/Documentation/Archive/22.11/wiki-page.view?name=releaseNotes2211> — **November 2022**.
- **Add samples to multiple freezer locations in a single step.**
- **[P] Workflow Editor role** — *"granting the ability to create and edit
  workflow jobs and picklists."*
- **Editor without Delete role** (CE-side): *"Users with this role can read,
  insert, and update information but cannot delete it."* This is the exact role
  `AGENTS.md` §3 requires the LabKey bridge API key to be restricted to.
- **[P] Notebook review assignable to a user group**, for workload balancing.
  (PR-025.)
- **[P] Notebook amendments**: *"Easily capture amendments to signed Notebooks
  when a discrepancy is detected … tracking the events for integrity."*
  (CON-004 — OSM requires an amendment to create a new revision without
  disturbing the signed one.)
- **ELN referential protection**: *"By prohibiting sample deletion when they are
  referenced in an ELN, Sample Manager helps you further protect the integrity
  of your data."*
- **[P] Assay results as a Sample Finder filter** — *"helping you find samples
  based on characteristics like cell viability."* Explicitly *"With the
  Professional Edition"*. This is FR-039's assay-threshold facet, and it is two
  paywall tiers up.
- **[P] Structured user-defined fields on workflow**: *"Searchable, filterable,
  standardized user-defined fields on workflow enable teams to create structured
  requests for work, define important billing codes for projects and eliminate
  the need for untracked email communication."* OSM's job model (FR-017, FR-033)
  has no user-defined field concept; see §7.
- **Aliquot-specific fields**: *"Administrators can control which parent sample
  fields are inherited and which can be set independently for the sample and
  aliquot."* A genuine gap in the OSM specification — see §6 and FR-068.
- **Sample ancestors usable in naming patterns.**
- Group management for permissions.
- Biologics: **sample Timeline generalised** — *"Before you had to dig through
  the audit tables to piece together the event history of a sample but now each
  sample's history can be easily viewed in an understandable way on the
  Timeline."*
- Biologics: **send sample information directly to BarTender**; **[P] aliquoting
  of media batches and raw materials**.
- **New Storage API** (CE-side client APIs): *"New Storage API available in Java,
  JavaScript, Python, and R for programmatically creating and updating
  freezers."* — worth a verification: an API for a capability whose service
  (`InventoryService`) returns `null` in CE.

### 23.3
<https://www.labkey.org/Documentation/Archive/23.3/wiki-page.view?name=releaseNotes233> — **March 2023**.
- **Sample expiration dates** — *"making it possible to track expiring
  inventories."* New reserved field `exp.material.materialExpDate`; the notes
  warn that a user field of that name will lose its data on upgrade. OSM has no
  expiry concept; see §6 and FR-069.
- **Storage generalised beyond freezers**: *"Storage management has been
  generalized to clearly support non-freezer types of sample storage."* OSM's
  FR-028 already models generic nodes; this confirms the shape.
- **Multiple BarTender label templates**, selectable at print time.
- **[P] ELN signing requires re-authentication**: *"To submit a notebook for
  review, or to approve a notebook, the user must provide an email and password
  during the first signing event to verify their identity."* This is FR-038's
  re-authentication, and it arrives in the commercial product **five years after
  electronic signatures did** (17.3). Note it is email **and password** — a
  federated-only OSM deployment must supply its own re-auth path (PR-006).
- **[P] ELN PDF carries the full review and signing event history**, with a
  consistent footer and entries starting on a new page. (PR-026.)
- **[P] Projects (subfolders) in the Professional Edition**, with the constraint
  *"Data structures like Sample Types, Source Types, Assay Designs, and Storage
  Systems must always be created in the top level home project."*
- Samples added to storage in the order they appear in the selection grid.
- CE: **built-in system fields shown in the field editor and toggleable**;
  reserved-field churn on `exp.materials` and `inventory` announced.
- **[P] Compliance**: *"PHI access control and compliance logging have been
  improved … LabKey SQL queries using PIVOT, OUTER JOINs, and expression columns
  are now permitted with compliance logging enabled."*
- CE: folder archives now carry file-browser settings and custom study security.

### 23.7
<https://www.labkey.org/Documentation/Archive/23.7/wiki-page.view?name=releaseNotes237> — **July 2023**.
- **Storage locations defined in-app** — the 21.11 *"contact us"* caveat is
  finally retired: *"Define locations for storage systems within the app."*
- **Create freezer hierarchy during sample import** — build the storage tree from
  the import file. (A genuinely useful intake shape OSM does not specify; §7.)
- **Sample amount at registration**: *"Add the sample amount during sample
  registration to better align with laboratory processes."* With the schema
  consequence: *"StoredAmount, Units, RawAmount, and RawUnits field names are now
  reserved."* These are the `DOUBLE PRECISION` columns
  `docs/labkey-ce-ground-truth.md` warns about; OSM uses `NUMERIC` (ADR-0002).
- **Sample Finder extended to the sample's own properties** — *"find samples by
  sample properties, as well as by parent and source properties."*
- **Built-in Sample Finder reports**: *"help you track expiring samples and those
  with low aliquot counts."* Saved queries as shipped reports; OSM has no
  equivalent concept. See §7.
- **[P] Move samples, sources, assay runs and notebooks between projects.**
- **[P] Cross-project data leakage closed**: *"Enhanced security by removing
  access or identifiers to data in different projects in lineage, sample
  timeline and ELNs."* A lineage graph that spans a permission boundary leaks
  *identifiers* even when it does not leak rows. Directly relevant to PR-029's
  RLS acceptance test, which must cover the lineage and timeline paths, not only
  the sample grid.
- **[P] Audit log retention configurable**: *"Administrators can configure the
  retention time for audit log events."* Note the direction of travel — the
  premium feature is the ability to **delete** audit history. Under ADR-0003 an
  OSM audit event is never deleted; retention applies to domain data (FR-062).
- **[P] "My Tracked Jobs"** — follow workflow jobs you are not assigned to.
- **[P]** Assay result grids can show per-row created/modified by and when.
- **[P] Sample Status values may only be defined in the home project**, with a
  destructive upgrade note (unused custom statuses in sub-projects are deleted).
- CE: sample types gain default system fields for storage and aliquot
  information; storage amount and units accepted on insert.
- CE: **folder archive can be exported metadata-only** (all data excluded) —
  useful for PR-032's portal delivery.

### 23.11
<https://www.labkey.org/Documentation/Archive/23.11/wiki-page.view?name=releaseNotes2311> — **November 2023**.
- **Move samples in storage** using the same interface as adding them, plus a
  direct *"Move Samples in Storage"* grid action. (FR-029.)
- **Box preview when adding to storage** — *"users will see more information
  about the target storage location including a layout preview for boxes or
  plates."* (PR-020.)
- **Box size raised to 50 rows** — *"to accommodate common slide boxes."*
  Confirms row labelling must work beyond 26 rows, which is exactly PR-016's
  acceptance criterion.
- **Sources gain lineage**: *"Sources can have lineage relationships, enabling
  the representation of more use cases."*
- **Calculated available aliquot count and amount**, *"based on the setting of
  the sample's status"* — i.e. status participates in an availability
  calculation even though it enforces nothing. (See §6.)
- **Amount updated during discard from storage.**
- `sampleCount` and `rootSampleCount` naming-pattern elements.
- Storage-location paths summarised for display when long.
- Grid settings (filters, sorts, paging) persist across navigation.
- CE: **per-field uniqueness constraint** — *"Individual fields in Lists,
  Datasets, Sample Types, and Data Classes, can be defined to require that every
  value in that column of that table must be unique."* The bridge can therefore
  enforce `osm_id` uniqueness downstream (FR-054).
- CE: **audit log indexing by container and user**, with an upgrade-time warning
  for large audit tables.
- CE: password strength; **[P] TOTP two-factor authentication**.
- CE: *"Users of the Community Edition will no longer be able to opt out of
  reporting usage metrics to LabKey."*

### 24.3
<https://www.labkey.org/Documentation/Archive/24.3/wiki-page.view?name=releaseNotes243> — **March 2024**.

From this release the Sample Manager section is itself split into
**Professional Edition Features** and **Starter Edition Features** — a
second paywall inside the premium product.

Professional Edition:
- **Workflow templates editable** before any job is created from them.
- **[Reasons required] configurable**: *"The application can be configured to
  require reasons (previously called 'comments') for actions like deletion and
  storage changes. Otherwise providing reasons is optional."* A configurable
  "reason for change" on a mutation is 21 CFR 11 vocabulary; OSM's audit model
  (ADR-0003) has no reason field. See §6 and FR-070.
- **API keys generated from inside the application**, *"for accessing client APIs
  from scripts and other tools."*
- ELN: **all notebook signing events require username and password**
  (strengthened from 23.3's "first signing event"); reference counts in the
  details panel; **workflow jobs referenceable from a notebook**; table of
  contents includes in-entry headings and day markers.
- Workflow templates can have **editable assay tasks**.

Starter Edition:
- **Choose fill order and starting position** when storing or moving into a box.
- **Discard defaults the status to "Consumed"** *(user-adjustable)*.
- Storage browse position remembered; storage path copyable with separators.
- **Sample Finder "Equals All Of"** — find samples sharing up to 10 common
  parents or sources.
- **Search for samples by storage location**: *"Storage unit names and labels are
  now indexed to make it easier to find storage in larger systems."*
- **Deletion guard on occupied storage**: *"Only an administrator can delete a
  storage system that contains samples. Non-admin users with permission to
  delete storage must first remove the samples from that storage."*
  (PR-016 acceptance: *"A node holding samples cannot be deleted."*)
- Samples movable to **multiple storage locations at once**; new storage units
  creatable while adding samples.
- Lineage display raised to **10 levels** in the grid view customiser.
- `:withCounter` made case-insensitive.
- CE: API keys can be set to expire in six months; `Date`/`Time` field types.

### 24.7
<https://www.labkey.org/Documentation/Archive/24.7/wiki-page.view?name=releaseNotes247> — **July 2024**.

Premium Edition:
- **Custom ELN certification language**: *"Customize the certification language
  used during ELN signing to better align with your institution's
  requirements."* The words a signer attests to are configurable. OSM §7 binds a
  content hash to the signer but does not specify the attestation text; see §6
  and FR-078.
- **Notebook Review Timeline**: *"More easily understand Notebook review history
  and changes including recalls, returns for changes, and more."* Recall and
  return-for-changes are ELN states OSM's five-state machine (FR-037) does not
  have. See §6, FR-077.
- **Reason required on notebook recall** (configurable).
- **Workflow jobs cannot be deleted if referenced from a notebook.**
- Workflow templates copyable.
- **Reason for update, not only for deletion**: *"Administrators can set the
  application to require users to provide reasons for updates as well as other
  actions like deletions."*
- Cross-project: add samples to any project without navigating there; edit
  samples across multiple projects; multi-select destination projects on move.

Starter Edition:
- **Custom colours per sample status.**
- **Print a box view**: *"Easily download and print a box view of your samples to
  share or assist in using offline locations like some freezer 'farms'."* An
  offline working mode OSM does not specify; see §7.
- **Reason for Update on sample, source or assay edits**: *"Users can better
  comply with regulations by entering a 'Reason for Update'."*
- **Search storage units by name or label** when adding or moving.
- **Automatic or manual fill** when adding to storage.
- Sample Finder over any user-defined sample property, and over user-defined
  fields on parents and sources.
- Lineage graphs redrawn by generation; display raised to **20 levels**.
- CE: **Sample Type Designer and Source (Data Class) Designer roles** — narrow
  design authority, separate from Editor. (FR-047 has a single Project admin;
  LabKey splits designer from editor. See §6, FR-080.)
- CE: **PHI columns can be excluded when creating a folder from a template.**
- CE: new audit event type for Module Properties changes.

## 4. Era III — the split, 24.11 to 26.11

From 24.11 the LabKey Server (SDMS) release notes **stop carrying sample
management**. Every release from 24.11 onward says only:

> *"Sample Manager Feature Updates / LabKey LIMS Feature Updates / Biologics
> LIMS Feature Updates … Learn more about Premium Editions of LabKey Server
> here."*

and links out to the LIMS Suite release notes. §5 of this document is where
those go, and §5 also carries the reconciliation.

**This is why a survey of the server release notes alone under-reports the
domain by roughly two-thirds after 2024.** Anyone repeating this exercise from
`prevreleases` and stopping there will conclude, wrongly, that LabKey stopped
developing sample management in 2024.

### 24.11
<https://www.labkey.org/Documentation/Archive/24.11/wiki-page.view?name=releaseNotes2411> — **November 2024**.
- **The split happens.** The page's "Other LabKey Products" block now lists
  *Sample Manager Release Notes*, *LabKey LIMS Release Notes* and *Biologics
  LIMS Release Notes* separately. LabKey LIMS is a new product name here.
- **[P] "Calculation" fields** in lists, datasets, sample, source and assay
  definitions.
- CE: linking sample data to a visit-based study by **visit label** rather than
  `sequencenum` (CON-009).
- CE: **API key descriptions**; folder file-root size reporting; changing a
  database password invalidates that login's sessions.
- **Deprecated**: *"You will no longer have the 'Advanced import options' of
  choosing objects during import of folders, as well as having folder imports
  applied to multiple folders."* (Removed in 25.11.)
- All specialty assays now distributed only to clients actively using them.

### 25.3
<https://www.labkey.org/Documentation/Archive/25.3/wiki-page.view?name=releaseNotes253> — **March 2025**.
- **Support for FreezerPro integration has been removed.**
- **Support for SampleMinded integration has been removed.**
  Together with the 21.3 specimen removal, these close the last three routes by
  which a Community Edition user could have had *any* freezer or vial data in
  LabKey. As of 25.3, CE has none, from any direction.
- CE: names of Sample Types, Source Types and Assay Designs may not contain
  certain special characters or internally reserved substrings — a validation
  rule the bridge must mirror (PR-031).
- CE: strong Content-Security-Policy by default; read-only HTTP request timeout;
  upload extension allowlist.

### 25.7
<https://www.labkey.org/Documentation/Archive/25.7/wiki-page.view?name=releaseNotes257> — **July 2025**.
- **[P]** *"A new validator will identify external images referenced from
  Electronic Lab Notebooks."* An ELN that renders a remote image leaks a
  read-receipt to the image host. Worth carrying into PR-024.
- CE: **"Site Administrators" and "Site Developers" groups no longer created by
  default**; permissions relying on them must be reassigned.
- Nothing else in the sample domain — it all moved to §5.

### 25.11
<https://www.labkey.org/Documentation/Archive/25.11/wiki-page.view?name=releaseNotes2511> — **November 2025**.

The most consequential release for OSM's audit and bridge work, and all of it
is **Community Edition**:

- *"**Detailed audit logging is automatically enabled for Samples, Sources, Data
  Classes, and Assay Data**, ensuring greater compliance and confidence that all
  user actions, particularly those occurring via Client APIs, are fully
  tracked."*
- *"**API users are now prevented from reducing the audit level below the
  effective default** or the administrator-configured value, bolstering
  compliance requirements."* A caller can no longer pass `auditBehavior: NONE`
  to write silently. This changes what the OSM bridge can and cannot suppress
  downstream, and it should be verified against the running server rather than
  believed.
- *"Transaction auditing has been improved by consolidating all relevant
  information in one location in the audit log."*
- *"Audit log now records **the method used** for insert, update, and delete
  operations."*
- Detailed assay-result logging shifts from many Experiment Events to linked
  Query Update Events, with a single summary Experiment Event per batch.
- The audit log records both original and generated file names when an upload is
  auto-renamed.
- **Removed**: advanced folder-archive import options (selective object import,
  multi-folder application).
- Removed: object-level discussions; the legacy union-of-all-audit-event-tables
  query is deprecated.

### 26.3
<https://www.labkey.org/Documentation/Archive/26.3/wiki-page.view?name=releaseNotes263> — **March 2026**.
- **[P] MCP Server**: *"Enables users to ask questions about domains and data
  structures, providing a new way to explore and understand how data is
  organized within the system."* Premium. This is the same subsystem
  `docs/labkey-ce-ground-truth.md` finds present-but-inert in CE
  (`NoopMcpService`, `isEnabled()` false) — the release notes and the source
  agree, which is worth recording as a rare case where they do.
- **[P]** *"Audit Log Maintenance feature has been **moved from the Professional
  to the Starter edition**."* LabKey moves audit retention *down* a tier; it is
  still not in Community.
- **[P] Improved lineage querying**: *"search the lineage object for all
  ancestors and descendants."*
- CE: **audit coverage for Grid Views**; the role **"See Audit Log Events" is
  now assignable per project and folder** rather than site-wide only — the
  granularity OSM's Auditor role (CON-006) needs.
- CE: **indexes addable to columns in the field editor** — relevant to the
  bridge's downstream query performance.
- **Workflow tables moved from the `sampleManagement` schema to a new `workflow`
  schema** (introduced 26.1). Any OSM query or publish path that hard-codes
  `sampleManagement.*` for workflow will break.
- Client APIs can query and update samples **by `RowId`**; LSID no longer
  required.
- Java 25 required.

### 26.7
<https://www.labkey.org/Documentation/wiki-page.view?name=releasenotes267> — **July 2026**.
- **[P] MCP Server** and **[P] MCP-Enabled SQL Access**: *"AI agents connected to
  the MCP Server can now read and query data from any schema or table the
  authenticated user has permission to access, using the new 'executeSQL' tool.
  Query results respect existing container and row-level permissions."*
  Note the security model, and note that it is the model `docs/gap-analysis.md`
  already quotes LabKey as being candid about: the bound is the credential, not
  the tool surface. OSM §18 takes the opposite position (CON-012, ADR-0006).
  An `executeSQL` tool is precisely the tool PRO-009 forbids OSM from exposing.
- **[P] Calculated Column Expression Assistant** — plain language to LabKey SQL —
  and an **AI-Backed Product Features flag** controlling it independently of the
  MCP flag.
- CE: **Role-Restricted API Keys**: *"API keys can now be restricted to a
  specific security role (for example, Reader or Editor), **as a way to impose
  appropriate limits on AI agents, tools, and scripts**."* This is the mechanism
  `AGENTS.md` §3 already requires for the bridge key, and LabKey now states the
  agent-limiting rationale explicitly.
- CE: *"Limit Login Attempts"* moved to Community Edition.
- CE: `frame-ancestors` CSP directive selectable; configurable terms-of-use
  acceptance interval.
- **Deprecated — matters for the bridge**: *"**Derive Samples Button Removed** —
  The 'Derive Samples' button has been removed from data grids in LabKey SDMS.
  Also, the link 'Derive samples from this sample' has been removed from the
  sample details page."* The notes remove the **UI**; they do not say the
  `experiment-derive.api` action is gone. **Unverified either way — do not
  assume.** A verification is queued in PR-039.
- *"Actions that execute mutating SQL … triggered via GET requests are no longer
  allowed in production deployments."*
- *"Inactive users now have no permissions. Any ETL or file watcher configured to
  run as an inactive user will start to fail."* A deactivated bridge service
  account now fails closed — good, and worth a runbook line (PR-038).
- **26.7 is the last release supporting Microsoft SQL Server as the primary
  database.**

### 26.11
<https://www.labkey.org/Documentation/wiki-page.view?name=releasenotes2611> — **in development** at the time of harvest; the page says *"LabKey SDMS version 26.11 is in development. Highlights so far."* Treat as provisional.
- `${rLabkeySessionId}` deprecated in pipeline and transform scripts — *"new
  scripts should use `${apikey}` instead."* Confirms the direction ADR-0008
  already takes.
- Transform scripts must live in the design container's `@scripts` directory or
  come from a module.
- Pipeline job deserialisation validated against a class allowlist.
- LabKey SQL gains `IS [NOT] DISTINCT FROM`.
- Nothing in the sample domain; it is all in §5.

## 5. Part 3 — the LIMS Suite release notes (verification pass)

Source: <https://www.labkey.org/limshelp/wiki-page.view?name=limsSuiteReleaseNotes>
(HTTP 200), plus two pages linked from it:
<https://www.labkey.org/limshelp/wiki-page.view?name=limsApiReleaseNotes> (200)
and <https://www.labkey.org/Documentation/Archive/21.3/wiki-page.view?name=bioReleaseNotes> (200).

### The Part 1 method does not apply here

The task assumed the LIMS notes would be per-release pages like the server
archive. **They are not.** `limsSuiteReleaseNotes` is a **single consolidated
page**. All 369 `href`s in its body and navigation tree were parsed; **none**
points at a per-version LIMS release-notes page, no `/limshelp/Archive/…` URLs
exist, and the navigation tree has exactly one child page
(`limsApiReleaseNotes`). No URL was guessed, so there were no 404s.

| | Count |
| --- | --- |
| Pages enumerated | 3 |
| Pages fetched (200) | 3 |
| Failed | 0 |
| Release sections on the consolidated page | 83 |
| Individual release items extracted | 415 |

Release cadence is **monthly** (26.9 down to 20.3, plus 17.1 for the Biologics
launch and four Extended Support Releases). The server release notes are
four-monthly. That alone guarantees version disagreement, and §6 quantifies it.

### The edition marking is a different mechanism

This page **does not use the premium star at all** — `fa fa-star-o` appears zero
times. It uses per-item edition badges instead:

```html
<span class="rnbadge rnsm"   data-tip="Feature available in Sample Manager Starter and above">
<span class="rnbadge rnpro"  data-tip="Feature available in Sample Manager Professional and above">
<span class="rnbadge rnlims" data-tip="Feature available in LIMS Starter and above">
<span class="rnbadge rnent"  data-tip="Feature available in LIMS Enterprise and above">
<span class="rnbadge rnbio"  data-tip="Feature available in Biologics LIMS">
```

Badges are cumulative upward, so the **lowest** badge present is the edition
that first provides the feature. That is what is recorded below as
"SM Starter+", "SM Professional+", and so on.

> **Caution, recorded rather than resolved.** An HTML comment at the top of the
> page maps the badge classes in a way that contradicts the live `data-tip`
> text — the comment labels `rnbio` as "LIMS Enterprise" and `rnent` as
> "Biologics LIMS", i.e. transposed. The `data-tip` text is what renders to a
> reader, so `data-tip` is used here. Items badged `rnent`+`rnbio` but not
> `rnlims` are reported as "LIMS Enterprise+". If LabKey's comment is the
> correct one and the tooltips are wrong, those two tiers are swapped
> throughout §5. **No OSM decision should turn on the distinction between
> LIMS Enterprise and Biologics LIMS until this is confirmed with LabKey.**

**None of these editions is Community.** Every one of the 415 items below is
outside LabKey CE. The badge tells you *how far* outside.

### Other defects in the source, recorded not corrected

- **There is no 24.3 section.** The page jumps 24.4 → 24.2. Verified against the
  raw HTML; not an extraction artefact.
- **Nothing between 17.1 and 20.3.** That gap is covered only by the Biologics
  archive page.
- **Unfinished internal editing notes are published verbatim in the 24.4
  section**, e.g. *"Limited to 1000 things (this is in the modal, may not need
  docs, but may need them)"* and *"Materialized sample view is now the default
  but we don't talk about it."* They are reproduced as found.
- **Several items are truncated at a colon in the source** with no following
  list (23.3, 23.7, 23.1, 24.1, 22.11, 21.2). Incomplete on the page, not lost
  in parsing.
- **21.1's only entry is the bare string "Freezer Management"** with no
  description.
- **26.9 and 26.8 are labelled "Upcoming Release"** as of this harvest
  (2026-08-26) and are forward-looking.
- The ESR and patch headings (26.7.3, 26.3.14, 26.3.8, 25.7.8) carry **no date**.

### What only the LIMS notes reveal

These capabilities appear **nowhere in the 60 server release-notes pages** and
would have been missed entirely by Part 1:

| Capability | First seen | Edition | Why it matters to OSM |
| --- | --- | --- | --- |
| **Storage actions as workflow steps** — *"Five new workflow actions let you add, check in, check out, move, and remove samples from storage directly within a workflow job."* | 26.5 (May 2026) | LIMS Starter+ | OSM keeps storage pipelines (FR-058) and work pipelines (FR-059) strictly separate. LabKey unifies them. Genuine design input — see FR-075. |
| **Aliquot / derive / pool as workflow actions** | 26.4 | LIMS Starter+ | Same boundary question. |
| **Set Sample Status as a workflow action**, and setting the *parent's* status during aliquot/derive/pool, *"optionally removing the parent from storage"* | 26.6 | LIMS Starter+ / SM Starter+ | Couples §3 status, §5 storage and §6 workflow in one transaction. |
| **`CheckedOut` date/time column on sample grids** | 25.7.8 ESR | SM Starter+ | Check-out is a **timestamped attribute of the sample**, not only an event. OSM's TTL reservation (FR-031) needs the same denormalisation to be queryable. |
| **Identifying Fields** — up to 6 admin-chosen fields shown wherever a sample is picked, in tooltips, and inherited by derivatives | 24.11, 24.12, 25.10, 26.3, 26.7.3 | SM Starter+ | A named concept OSM has no equivalent of. See FR-071. |
| **Amount and Units enforced as a pair**; **negative amounts disallowed** | 25.10, 25.12 | SM Starter+ | Cheap, high-value invariants for PR-011/PR-013. |
| **Lineage relationships markable as required** | 24.10 | SM Starter+ | A sample type can demand a parent. OSM has no such constraint. |
| **Restricted lineage entities** — *"Entities you don't have access to in lineage views are now shown as restricted rather than being omitted, preserving full context without exposing details."* | 26.2 | SM Professional+ | The **opposite** choice from server 23.7, which removed identifiers outright. Two defensible designs; PR-029 must pick one deliberately. See CON-015. |
| **Storage unit barcode identification** — terminal storage units identified by barcode, *"globally unique across all projects on the server"* | 26.7 | SM Starter+ | OSM barcodes samples (PR-019), not slots or boxes. |
| **Storage change reasons**, and configurably **required** storage change reasons | 26.7 | SM Starter+ / SM Professional+ | Reinforces FR-070. |
| **Sample status as a lineage-graph filter**, hiding nodes while keeping connections between visible ancestors | 26.7 | SM Starter+ | A graph-rendering requirement OSM has not specified. |
| **Cross-folder import removed** — *"Importing samples, sources, or registry entries into a folder other than the current one is no longer supported."* | 26.7 | SM Starter+ | Direct constraint on the publish bridge: the outbox worker must POST into the target container itself. See CON-016. |
| **Terminology: "Remove" replaces "Discard"** for taking a sample out of storage; **"Folder" replaces "Project"** for a subcontainer | 24.10 | SM Starter+ | OSM's §3 status set uses `Discarded` for the *sample*, which LabKey now reserves for the *storage* action. Vocabulary collision in the bridge mapping. |
| **21 CFR Part 11 named, once** — an inline warning that a SAML "Skip Reauthentication" convenience *"may affect 21 CFR Part 11 eSignature requirements"* | 26.7.3 | SM Professional+ | The **only** occurrence of "21 CFR", "Part 11", "GxP" or "GMP" in the entire corpus surveyed — 60 server pages and 83 LIMS sections. See §7. |
| **MCP Server at LIMS Starter** | 26.4 | LIMS Starter+ | A *second*, separate MCP surface from the SDMS one (26.3). |
| **Audit: client APIs respect the system-configured level, the more detailed of the two wins** | 25.9 | SM Starter+ | Matches server 25.11's CE change; corroborates it. |
| **All audit events for a transaction viewable in one place** | 25.8 | SM Starter+ | LabKey's answer to transaction-scoped audit. OSM's is the hash chain (ADR-0003). |
| **Two-factor authentication configurable by LabKey** | 25.11 | SM Starter+ | |
| **Plate sets, plate campaign modelling, multi-plate hit selection, liquid-handler instructions** | 24.11 – 25.3 | LIMS Enterprise+ | An entire domain OSM does not model. See §7 — recommended **out of scope**. |
| **Folders archivable**; **workflow job templates archivable** | 24.11, 26.8 | SM Professional+ | Archive-instead-of-delete as a first-class state. |
| **Notebook recall email to the author**; **administrator may amend any notebook** | 25.11, 24.11 | SM Professional+ | ELN state-machine detail beyond FR-037. |

### Where the LIMS notes correct Part 1

| Claim from the server notes | Correction from the LIMS notes |
| --- | --- |
| Clone Freezer first appears in 21.7 | *"Copy a Freezer definition"* is **21.5 (May 2021)**. |
| 21.11 adds a project-wide name prefix for Samples and Sources | The same item carries *"**Removed in version 22.12.**"* Part 1 alone leaves a removed feature looking current. |
| Freezer management arrives 21.3 | LIMS **21.1 (January 2021)**, with storage-menu and storage-location groundwork visible in **20.9** and **20.8** (*"in anticipation of future Freezer Management support"*). |
| Aliquots and picklists arrive 21.7 | LIMS **21.6 (June 2021)**. |
| Sample Timeline arrives 20.7 | LIMS **20.5 (May 2020)**. |
| Sources arrive 20.7 | LIMS **20.4 (April 2020)** — *"Define Sources for Samples — a source could be an individual, cell line, or lab."* |
| BarTender arrives 20.11 | LIMS **20.10 (October 2020)**. |
| Barcode generation arrives 21.7 | LIMS **21.4 (April 2021)**. |
| Storage Editor / Storage Designer roles arrive 22.3 | LIMS **22.2 (February 2022)**. |
| Sample Manager "ready for preview" 19.3 | The product **launch** is LIMS **20.3, March 2020** — *"LabKey Sample Manager is Launched!"* Preview and launch are different events; both are real. |

### Where the two sources disagree outright

1. **The ELN's edition.** Server 22.7 states the ELN is *"Available in the
   Professional Edition of Sample Manager and with the Enterprise Edition of
   LabKey Server."* The LIMS page badges its 22.7 ELN introduction for **all
   five editions including SM Starter**, while badging every subsequent ELN item
   SM Professional+. The badges contradict themselves and the server notes.
   **Treated here as SM Professional+**, following the server notes and the
   later badges — but recorded as unresolved.
2. **Product-tier naming.** The server notes speak of "Sample Manager Starter /
   Professional"; the LIMS page adds **LIMS Starter** (launched 24.10) and
   **LIMS Enterprise** (*"LIMS Enterprise Edition is now available"*, 26.3).
   `docs/gap-analysis.md`'s five-tier description predates 26.3 and does not
   name LIMS Enterprise. It is not wrong, but it is now incomplete.
3. **Where MCP lives.** Server 26.3/26.7 put the MCP Server in premium *SDMS*;
   LIMS 26.4 puts an MCP Server at *LIMS Starter*. Whether these are one
   subsystem surfaced twice or two is **not determinable from the release notes**
   and is not asserted here.
4. **What Part 1 over-claimed.** The server notes list Sample Manager features
   under one heading with no tier breakdown until 24.3. Reading them alone, a
   reasonable person concludes the whole of Sample Manager sits at one price.
   It does not: **freezer management, check-in/check-out, picklists, aliquots,
   barcodes, sample status and the Sample Finder are all SM Starter**, while
   **the ELN, workflow, cross-project moves, API keys and required-reason
   configuration are SM Professional+**, and **workflow-integrated storage
   actions are LIMS Starter+**. Part 1 over-states the paywall on storage and
   under-states it on workflow and the ELN.

### 5.1 Full LIMS Suite inventory

Extracted mechanically from the page's own `rntable` rows: item text, the
lowest edition badge, and in brackets the `limshelp` documentation page each
item links to (resolve as
`https://www.labkey.org/limshelp/wiki-page.view?name=<page>`). 83 release
sections, 415 items.
<!-- 83 release sections, 415 items -->

#### Release 26.9, September 2026 Upcoming Release

- Derive Samples and Sources from Workflow Tasks - Add "Derive Samples" and "Derive Sources" actions to a workflow job template task, so new samples or sources can be generated directly as a standardized step in a job. [jobTemplate] — **LIMS Starter+**

#### Release 26.8, August 2026 Upcoming Release

- Add Sources to Workflow Jobs - Add sources and registry sources to a workflow job the same way samples are added, so lab work can start at the right level from the start. [startJob] — **SM Professional+**
- Bulk Sequence Registration - Sequence registration can now be done in bulk by importing GenBank or FASTA files. [bulkEnt] — **Biologics LIMS+**
- Workflow Jobs Grid Views - Add or remove columns on the Workflow Jobs grid, including a column for job creation date, to arrange the list the way your lab prioritizes work. [manageQueue] — **SM Professional+**
- Archive Workflow Job Templates - Archive outdated workflow job templates to hide them from the template dropdown without affecting historical jobs, and restore them at any time. [manageJobs] — **SM Professional+**
- Schema Browser Available to Administrators - Application Administrators can now see the Schema Browser link in the apps, for easier access to schema and table details when working with the API. [sampleDash] — **SM Professional+**
- Register New Parents During Registration - Register parent entities, such as parent nucleotide and protein sequences while registering child entities. [createEntity] — **SM Starter+**

#### Release 26.7.3

- ELN Access Across Folder Moves - Audit history and attachments now display and work correctly when a notebook is viewed from a folder other than the one where it was created. [crossFolder] — **SM Professional+**
- Ancestor-Sourced Identifying Fields on Derivatives - Identifying fields inherited from an ancestor sample now display and save the correct values when creating derivatives. [deriveSamples] — **SM Starter+**
- ELN Signing: Skip SAML Reauthentication - SAML configurations can include a Skip Reauthentication setting so already-authenticated users sign ELN notebooks without an identity-provider redirect, with an inline warning that skipping may affect 21 CFR Part 11 eSignature requirements. [elnReview] — **SM Professional+**

#### Release 26.7, July 2026

- Storage Unit Barcode Identification - Administrators can now configure terminal storage units to be identified by barcode, enabling globally unique identification across all projects on the server. [createFreezer] — **SM Starter+**
- Storage Change Reasons - Provide a reason for sample moves, storage unit relocations, and storage definition edits, with each reason tracked in the audit log. [audits] — **SM Starter+**
- Require Storage Change Reasons - Configure storage actions to require a reason for sample moves, storage unit relocations, and storage definition edits. [audits] — **SM Professional+**
- Lineage Filtering by Sample Status - Filter the lineage graph by sample status to hide selected nodes while maintaining connections between visible ancestors and descendants. [deriveSamples] — **SM Starter+**
- Delete Domain from Designer - The option to delete a Sample Type, Source Type, Assay Design, or Freezer is now located on the designer page for that domain, reducing the risk of accidentally deleting an entire domain while intending to delete individual records. [manageAssayDesign] — **SM Starter+**
- Cross-Folder Import Removed - Importing samples, sources, or registry entries into a folder other than the current one is no longer supported. — **SM Starter+**
- View Inactive Site Users - The Application Users manage menu now shows "View Inactive Site Users" instead of "View Inactive Application Users". [manageUsers] — **SM Starter+**
- Puppeteer Service HTTPS Requirement - The Puppeteer service URL must now be https or localhost; users attempting to export to PDF with an http URL will receive an error message. [puppeteer] — **SM Professional+**
- Part 11-Compliant eSignatures for SSO - ELN signature authentication for SSO-enabled teams now routes through a shared pathway, meeting Part 11 electronic signature requirements. [elnReview] — **SM Professional+**
- Unidentified Molecules - Register molecules with unidentified or excluded components, then identify them later from the molecule details page once all components have themselves become identified. [moleculeRegistry] — **Biologics LIMS+**

#### Release 26.6, June 2026

- Molecule and Protein Sequence Bulk Import by File - Improved bulk import now includes simplified data formats and provides imports for Molecules, their components, and stoichiometry. [bulkEnt] — **Biologics LIMS+**
- New Workflow Action: Set Sample Status - A new workflow action lets you update sample status directly within a workflow step, keeping sample state current as work progresses without switching to a separate view. [jobTemplate] — **LIMS Starter+**
- Workflow Aliquot, Derive, and Pool: Parent Status Update - The Aliquot, Derive, and Pool workflow actions include the option to update the parent status at the same time, so sample records stay accurate from the moment a new sample is created. [jobTemplate] — **LIMS Starter+**
- Calculated Column Expression Assistant - Describe the calculation you need in plain language and let AI generate the LabKey SQL expression for you. Access it from the Calculated Column field type in the domain designer, or via "Get Help from AI" when a calculated column has invalid SQL. [propertyFields] — **SM Professional+**
- Set Parent Sample Status During Aliquot, Derive, or Pool - When aliquoting, deriving, or pooling, you can update the parent sample's status in the same step, and optionally remove the parent from storage. [aliquots] — **SM Starter+**
- Source Names Editing via Update from File - Source Names can now be edited via update from file when RowId is provided. [viewSourceTypes] — **SM Starter+**
- Limit Login Attempts - "Limit Login Attempts" is now available in all editions of the LIMS Suite. — **SM Starter+**

#### Release 26.5, May 2026

- Workflow Storage Actions - Five new workflow actions let you add, check in, check out, move, and remove samples from storage directly within a workflow job. [jobTemplate] — **LIMS Starter+**
- Streamlined Workflow Layout - The workflow interface has been reorganized to surface tasks more quickly and reduce scrolling. — **SM Professional+**
- New Unit Type Options - Four new options are available under the "Other" unit type: Organisms, Vials, Tubes, and Syringes. [createSampleType] — **SM Starter+**
- Multi-Value Text Choice Fields - Text Choice fields now support multiple selections in Sample Types, Data Classes, Assay Results, Lists, and Datasets — giving teams more flexibility when capturing metadata that requires more than one value. [multiChoiceField] — **SM Starter+**
- Lookup Field Availability - Sample Manager Professional & LIMS Starter customers will no longer see the field type 'Lookup' in Assay Designs as intended. Existing lookup fields will continue to work, but consider converting these fields to Text Choice for guaranteed support going forward. — **SM Professional+**
- Terminal Storage Location in Sample Grids - The terminal storage location field can now be displayed as a column in sample grids, making it easier to see exactly where samples are stored at a glance. [customViews] — **SM Starter+**
- 2FA Reset for App Admins - Application administrators can now reset TOTP authentication settings for users directly within the app. [manageUsers] — **SM Starter+**
- Compound Identification and Molecule Integration - Compounds are now registered with enforced uniqueness and can be incorporated as components of Molecules, providing better support for antibody drug conjugates and enzymes. [biocompounds] — **Biologics LIMS+**

#### Release 26.4, April 2026

- Inactive and Deactivated User Visibility Improvements - Admins can now view all site users regardless of read access. Deactivated users are clearly prefixed in groups and permissions, providing better visibility into historical access and strengthening audit readiness. [manageUsers] — **SM Starter+**
- Workflow Actions - You can now aliquot, derive, and pool samples directly within a workflow job, enabling standardized sample processing as part of automated workflows. [jobTemplate] — **LIMS Starter+**
- MCP Server - Enabling users to ask questions about LIMS domains and data structures. This provides a new way to explore and understand how data is organized within the system. — **LIMS Starter+**
- Unidentified Sequence Registration - Nucleotide and protein sequences can be registered before knowing the sequence. Sequence data can be added later so that related work can progress. — **Biologics LIMS+**

#### Release 26.3.14 - Extended Support Release (ESR)

- Security Enhancements - A number of security enhancements to improve system security and reliabilty. — **SM Starter+**

#### Release 26.3.8 - Extended Support Release (ESR)

- MCP Server - Enabling users to ask questions about LIMS domains and data structures. This provides a new way to explore and understand how data is organized within the system. — **LIMS Starter+**
- Lookup Field Availability - Sample Manager Professional customers will no longer see the field type 'Lookup' in Assay Designs as intended. Existing lookup fields will continue to work, but consider converting these fields to Text Choice for guaranteed support going forward. — **SM Professional+**
- Terminal Storage Location in Sample Grids - The terminal storage location field can now be displayed as a column in sample grids, making it easier to see exactly where samples are stored at a glance. Also in 26.3.6. — **SM Starter+**

#### Release 26.3, March 2026

- LIMS Enterprise Edition is now available. — **LIMS Enterprise+**
- Text Choice Field Limit Increase - The maximum number of options allowed in Text Choice fields has increased from 200 to 500, allowing greater flexibility when defining controlled vocabularies. [propertyFields] — **SM Starter+**
- Expanded audit coverage - grid view configuration changes are now audited, providing a record of when views are created or modified and by whom. [audits] — **SM Starter+**
- Improved experience when adding samples to storage - When adding samples to a storage location, the Search for Samples grid now automatically includes Identifying Fields, making it easier to locate the correct samples quickly. [storeFreezer] — **SM Starter+**
- Exact text searches now supported using double quotes. — **SM Starter+**
- Better warnings for unknown fields - when importing cross-sample types, we provide better feedback for unknown fields. — **SM Starter+**
- File Update: Insert New Disabled - When updating data from a file, the 'insert new' option has been temporarily disabled. The option will be reinstated in a later release. Currently, when updating from a file, remove all columns that you do not intend to update, as blank columns in the file will cause all values from the target field to be removed. — **Biologics LIMS+**

#### Release 26.2, February 2026

- Column widths now adjust dynamically, allowing more columns to be visible at once with less horizontal scrolling. [gridBasics] — **SM Starter+**
- Configured URL links can now be opened in a new browser tab for easier comparison and multitasking. [fieldEditor] — **SM Starter+**
- Restricted Lineage Entities - Entities you don't have access to in lineage views are now shown as restricted rather than being omitted, preserving full context without exposing details. [deriveSamples] — **SM Professional+**
- Sample Status is available as a filter for "All Sample Types" in Sample Finder. [sampleFinder] — **SM Starter+**
- GenBank import improved - nearly all information GenBank files is captured on import, including the original file. — **Biologics LIMS+**
- Improved Molecule creation - Select protein sequences to kick off the molecule creation process. — **Biologics LIMS+**

#### Release 26.1, January 2026

- Support for multiple unit types provides improved inventory and material management. [createSampleType] — **SM Starter+**
- Move Workflow Jobs - Move workflow jobs to different folders to better reflect changes in projects or organization. [crossFolder] — **SM Professional+**
- Client APIs can query and update samples using the RowId value; using the LSID value is no longer required. — **SM Professional+**
- Sample Name Updates via File - Sample names (SampleId) can be updated via a file, when RowId is provided. — **SM Starter+**
- Workflow tasks now support sample filters, allowing you to control which samples are included at each step. [editJob] — **LIMS Starter+**
- Improved plot customization layout, axis, size, color, and per-series line controls. — **LIMS Starter+**

#### Release 25.12, December 2025

- Amount and Units Fields - Improvements have been made to ensure that the Amounts & Units fields function as paired fields. [importSampleSets] — **SM Starter+**
- Negative Amount Values Disallowed - Sample Manager now enforces that the Amounts field cannot have a negative value. [importSampleSets] — **SM Starter+**
- Identifying Fields - Identifying fields are now shown in more assay import scenarios. [identifyingFields] — **SM Starter+**

#### Release 25.11, November 2025

- Audit log on the method or webpage location used to insert, update, and delete records. — **SM Starter+**
- ELN Recall Email Notification - When an ELN notebook is recalled by an administrator, the author will now receive an email notification, improving visibility and timely follow-up. — **SM Professional+**
- Alphabetical Field Sorting - The Customize Grid View and Filter pop-up dialogs now list fields alphabetically, making it faster and more intuitive to find and select fields. — **SM Starter+**
- Two factor authentication is available for configuration by LabKey. Consult your Account Manager for changes. — **SM Starter+**
- Audit log used to insert, update, and delete records. — **LIMS Starter+**
- Error bars are available on Bar and Line charts. — **LIMS Starter+**
- Multiple charts can be displayed above data grids. Select up to 5 charts to display. — **LIMS Starter+**

#### Release 25.10, October 2025

- Amounts and Units Changes - Amount and Unit fields are now enforced as a pair—both must be completed together or left empty. [importSampleSets] — **SM Starter+**
- Required Fields in Workflow Jobs - Required fields in workflow jobs are now enforced during job creation, instead of during job completion. [jobTemplate] — **SM Professional+**
- Identifying Fields - Administrators can now set up to 6 identifying fields. [identifyingFields] — **SM Starter+**

#### Release 25.9, September 2025

- Improved Audit Logging Behavior - The LabKey Client APIs will now respect the audit level configured by the system to improve adherence to compliance and ease development. When both the system and API parameters specify an auditing level, the higher, more detailed level is applied. [audits] — **SM Starter+**
- Several improvements were made to overall system reliability and performance. — **SM Starter+**

#### Release 25.8, August 2025

- You can now view all audit events for a transaction in one place. [audits] — **SM Starter+**
- Duplicate File Rename Audit - The audit log now records original file names when duplicates are automatically renamed. [audits] — **SM Starter+**

#### Release 25.7.8 - Extended Support Release (ESR)

- Selection order is retained when editing in a grid. — **SM Starter+**
- Improved ELN Editing - ELN editors now get faster feedback when pasting images into an ELN: files pasted into an ELN now fail immediately if they can't be loaded. [troubleshootELNImage] — **SM Professional+**
- Improved import feedback - When attachment fields are supplied with data in a file import or file update for Sources, users will be provided an error message that Attachment data cannot be provided via a file. — **SM Starter+**
- CheckedOut Column in Sample Grids - The CheckedOut date/time stamp is now an available column in sample grids. [audits] — **SM Starter+**
- Assay Run Move Fix - We have addressed an issue with moving assay runs. Moving assay runs that have multiple file fields now associate correctly. — **SM Professional+**
- Cross-Type Import CheckedOut Fix - We have addressed an issue with cross-sample-type import or cross-folder sample import, where the CheckedOut column was being ignored. — **SM Starter+**
- Yes/No Field Import Fix - We have addressed an issue with cross-sample-type import and cross-folder sample import, where Yes/No text fields were being inadvertently converted to Boolean values. — **SM Starter+**
- Locked Status After Storage Removal Fix - We have addressed an issue where samples being removed from storage could not be assigned a Locked sample status type. — **SM Starter+**

#### Release 25.7, July 2025

- Improvements were made to address overall system reliability and performance. — **SM Starter+**
- Continued investment in automated testing and internal quality checks to support ongoing feature development. — **SM Starter+**

#### Release 25.6, June 2025

- Lineage details can be used in aliquot naming patterns. [aliquotids] — **SM Starter+**
- Users can enter a reason when they make changes to a Sample Type, Source Type, or Assay Design. [audits] — **SM Starter+**
- Sample Field Validation - Fields of type "Sample" can be set to validate that values already exist in the system. [propertyFields] — **SM Starter+**
- Several improvements were made to address overall system reliability and performance. — **SM Starter+**

#### Release 25.5, May 2025

- Several improvements were made to address overall system reliability and performance. — **SM Starter+**
- Continued investment in automated testing and internal quality checks to support ongoing feature development. — **SM Starter+**

#### Release 25.4, April 2025

- Several improvements were made to address overall system reliability and performance. — **SM Starter+**
- Continued investment in automated testing and internal quality checks to support ongoing feature development. — **SM Starter+**

#### Release 25.3, March 2025

- Rapidly find the plates and experiments in which samples have been used, and vice versa. — **LIMS Enterprise+**
- Automatically generate analytics like regressions and statistics to accelerate your work — **LIMS Enterprise+**

#### Release 25.2, February 2025

- Simplified Main Dashboard - The main dashboard has been simplified. [sampleDash] — **SM Starter+**
- Storage Location Memory - The last storage location is remembered on a per sample type basis, making it easier for users who work with different materials to return to the right locations. [storeFreezer] — **SM Starter+**
- Multiple Sample or SourceIDs can now be edited in the editable grid. [gridBasics] — **SM Starter+**
- Adding samples to workflow jobs has been streamlined. [startJob] — **SM Professional+**
- Workflow jobs, tasks, and notification subscriptions can be assigned by group as well as by individual user. [startJob] — **SM Professional+**
- Assay transform scripts can be configured to run when data is imported, updated, or both. — **LIMS Starter+**
- Use conditional formatting to selectively highlight field values in grids. — **LIMS Starter+**
- Support for advanced plate layouts using using dilutions. — **LIMS Enterprise+**
- Add Samples to an existing Plate Set. — **LIMS Enterprise+**
- Navigate from a plate set to any notebooks that reference it. — **LIMS Enterprise+**
- Edits to outlier exclusions will result in the rerunning of any transform scripts that are configured to run on update. — **LIMS Enterprise+**

#### Release 25.1, January 2025

- Creating or deriving samples of multiple types at once can now be done with a streamlined interface. [createSamples] — **SM Starter+**
- Consistent Lineage Entry - The process of adding lineage details when creating and deriving samples and sources is more consistent. [createSamples] — **SM Starter+**
- Special characters are not allowed in the names of structures like Sample Types, Source Types, and Assay Designs. [dataImport] — **SM Starter+**
- Folder-First File Import - When importing new samples and sources from a file, first navigate to the folder where you want to create them. [crossFolder] — **SM Professional+**
- Trendline for Line Charts - A trendline option has been added to the chart builder for Line charts. — **LIMS Starter+**
- Customize the downloadable template file for Samples, Sources, and Assay Designs. [downloadTemplate] — **LIMS Starter+**
- Users can now specify hit selection filter criteria on Assay fields. When a run is imported/edited the hit selections for the assay results will be recomputed and automatically applied based on these criteria. — **LIMS Enterprise+**
- Navigate from a sample to the plate(s) it has appeared on. — **LIMS Enterprise+**
- Perform many types of linear regression analysis and chart them. — **LIMS Enterprise+**
- Exclude outlier plate-based assay data points and have that reflected in calculations and charts. — **LIMS Enterprise+**

#### Release 24.12, December 2024

- Recently Added Storage Locations - The main dashboard shows "Locations Recently Added To" for easy access to recent storage locations. [sampleDash] — **SM Starter+**
- Improvements in creating and deriving samples and sources let you choose the type and number to create up front. [createSamples] — **SM Starter+**
- Use identifying fields when editing samples in grids and viewing tooltips during sample creation and derivation. [identifyingFields] — **SM Starter+**
- Workflow Assay Import Sample IDs - Importing assay data from a workflow job will now only choose relevant sample IDs. [completeTasks] — **SM Professional+**
- Plate sets can be referenced from an Electronic Lab Notebook. — **LIMS Enterprise+**

#### Release 24.11, November 2024

- Customize which Identifying Fields are shown when users choose samples or sources from dropdowns. [identifyingFields] — **SM Starter+**
- Date, time, and datetime fields are now limited to a set of common display patterns, making it easier for users to choose the desired format. [dateFormats] — **SM Starter+**
- Simplified Lineage and Storage Editing - A simplified interface for editing lineage and storage information replaces the previous additional tabs on editable grids. [editSamples] — **SM Starter+**
- Filter Element Limit - Contains/Equals One of, Does not equal one of are constrained to 200 elements when filtering. [gridBasics] — **SM Starter+**
- Include "Calculation" fields in your sample, source, and assay definitions that can perform calculations on any combination of system and user-defined fields. [propertyFields] — **SM Professional+**
- Folders that are no longer in use can be archived to hide them from view. [folders] — **SM Professional+**
- Administrator Notebook Amendment - An administrator may amend any notebook. [elnAmend] — **SM Professional+**
- In-App Chart Builder - The Chart Builder can be used from within the application to add and edit charts on grids. [bioCharts] — **LIMS Starter+**
- Campaign modeling with plate set hierarchy support. — **LIMS Enterprise+**
- Plan plates easier with graphical plate design and templating. — **LIMS Enterprise+**
- Automate routine analyses from raw data collected. — **LIMS Enterprise+**
- Multi-Plate Hit Selection - Perform hit selection from multiple, integrated results across plates and data types. — **LIMS Enterprise+**
- Generate instructions for liquid handlers and other instruments. — **LIMS Enterprise+**
- Automatically integrate multi-plate results including interplate replicate aggregation. — **LIMS Enterprise+**
- Dive deeper into plated materials to understand their characteristics and relationships from plates. — **LIMS Enterprise+**

#### Release 24.10, October 2024

- Lineage relationships can now be marked as required when creating or updating samples or sources. [deriveSamples] — **SM Starter+**
- Remove vs. Discard Terminology - The term "Remove" is now used instead of "Discard" when a sample is taken out of a storage system. [manageStored] — **SM Starter+**
- Folder vs. Project Terminology - The term "Folder" is now used instead of "Project" to describe a subcontainer or partition of data within the application. All data scoping, user access, and configuration options are unchanged. [folders] — **SM Starter+**
- BarTender URL Save Requirement - When configuring BarTender, you must first save the URL prior to being able to test the connection. [setupBarTender] — **SM Starter+**
- LIMS Starter is Launched! — **LIMS Starter+**
- Charts are added to LIMS Starter, making them an "inherited" feature set from other product tiers. [bioCharts] — **LIMS Enterprise+**

#### Release 24.9, September 2024

- More easily create storage during sample import by adding labels on terminal storage units. [freezerMigrate] — **SM Starter+**
- Make naming samples easier with the ability to name your samples based on source or sample ancestors regardless of hierarchy. [sampleIDs] — **SM Starter+**
- Sample Creation Order in Storage - When adding samples to storage, you can use the Sample Creation Order, i.e. the "reverse" of the default grid order. (docs | docs) [storeFreezer] — **SM Starter+**
- Resolved an issue with editing samples with mixed parent sample or source IDs. In certain scenarios, where projects were in use, samples being edited in the grid with sample or source parents whose sample IDs were a mixture of numeric and non numeric, lineage was unintentionally removed. — **SM Starter+**

#### Release 24.8, August 2024

- More easily get your sample templates to BarTender by exporting the "BarTender Template". [barTender] — **SM Starter+**
- Editable grids now validate entered values as you go, rather than waiting for save to check all entries. [gridBasics] — **SM Starter+**
- Resolved an issue with moving boxes and deleting storage hierarchy. In certain scenarios, boxes containing samples were unintentionally deleted when their previous location was simultaneously deleted while they were being moved. — **SM Starter+**

#### Release 24.7, July 2024

- Chart Export Menu - A new menu has been added for exporting a chart from a grid. [bioCharts] — **LIMS Enterprise+**

#### Release 24.6, June 2024

- More easily identify if a file wasn't uploaded with an "Unavailable File" indicator. [fileAttach] — **SM Starter+**
- Streamlined Add to Storage - The process of adding samples to storage has been streamlined to make it clearer that the preview step is only showing current contents. [storeFreezer] — **SM Starter+**
- Customize the certification language used during ELN signing to better align with your institution's requirements. [elnReview] — **SM Professional+**
- Workflow templates can now be copied to make it easier to generate similar templates. [manageJobs] — **SM Professional+**

#### Release 24.5, May 2024

- Assign custom colors to sample statuses to more easily distinguish them at a glance. [sampleStatus] — **SM Starter+**
- Easily download and print a box view of your samples to share or assist in using offline locations like some freezer "farms". [manageStored] — **SM Starter+**
- Use any user-defined Sample properties in the Sample Finder. [sampleFinder] — **SM Starter+**
- More easily understand Notebook review history and changes including recalls, returns for changes, and more in the Review Timeline panel. [elnReview] — **SM Professional+**
- Administrators can require a reason when a notebook is recalled. [audits] — **SM Professional+**
- Add samples to any project without first having to navigate there. [crossFolder] — **SM Professional+**
- Cross-Project Sample Editing - Edit samples across multiple projects, provided you have the appropriate permissions. [crossFolder] — **SM Professional+**

#### Release 24.4, April 2024

- Maintenance release 24.4.1 addresses an issue with uploading files during bulk editing of Sample data. — **SM Starter+**
- Users can better comply with regulations by entering a Reason for Update when editing sample, source or assay data. [editSamples] — **SM Starter+**
- More quickly find the location you need when adding samples to storage (or moving them) by searching for storage units by name or label. [storeFreezer] — **SM Starter+**
- Choose either an automatic (specifying box starting position and Sample ID order) or manual fill when adding samples to storage or moving them. [storeFreezer] — **SM Starter+**
- More easily find samples in Sample Finder by searching with user-defined fields in sample parent and source properties. [sampleFinder] — **SM Starter+**
- Lineage graphs have been updated to reflect "generations" in horizontal alignment, rather than always showing the "terminal" level aligned at the bottom. [deriveSamples] — **SM Starter+**
- Hovering over a column label will show the underlying column name. [gridBasics] — **SM Starter+**
- Up to 20 levels of lineage can be displayed using the grid view customizer. [deriveSamples] — **SM Starter+**
- Administrators can set the application to require users to provide reasons for updates as well as other actions like deletions. [audits] — **SM Professional+**
- Moving entities between projects is easier now that you can select from multiple projects simultaneously for moves to a new one. [crossFolder] — **SM Professional+**
- Pagination of 400 for "Find Samples By" results. Limited to 1000 things (this is in the modal, may not need docs, but may need them) — **SM Professional+**
- Language for ELN Template is "Shared" instead of "Public"... — **SM Professional+**
- List Lookups that were too long weren't showing - now they will open 'above' and show. — **SM Professional+**
- Materialized sample view is now the default but we don't talk about it. — **SM Professional+**
- Sample Manager User Conference 2024 - Sample Manager User Conference 2024 — **SM Professional+**

#### Release 24.2, February 2024

- Sample Finder Equals All Of - In Sample Finder, use the "Equals All Of" filter to search for Samples that share up to 10 common Sample Parents or Sources. [sampleFinder] — **SM Starter+**
- Date and Time Field Types - Include fields of type "Date" or "Time" in Samples, Sources, and Assay Results. [propertyFields] — **SM Starter+**
- Users can now sort and filter on the Storage Location columns in Sample grids. [gridBasics] — **SM Starter+**
- Sample types can be selectively hidden from the Insights panel on the dashboard, helping you focus on the samples that matter most. [sampleDash] — **SM Starter+**
- Source Parent Clarification - The Sample details page now clarifies that the "Source" information shown there is only one generation of Source Parents. For full lineage details, see the "Lineage" tab. [viewSampleSets] — **SM Starter+**
- Up to 10 levels of lineage can be displayed using the grid view customizer. [deriveSamples] — **SM Starter+**
- Menu and dashboard language is more consistent about shared team resources vs. your own items. [sampleDash] — **SM Starter+**
- Configurable Action Reasons - The application can be configured to require reasons (previously called "comments") for actions like deletion and storage changes. Otherwise providing reasons is optional. [audits] — **SM Professional+**
- Developers can generate an API key for accessing client APIs from scripts and other tools. [myAccount] — **SM Professional+**

#### Release 24.1, January 2024

- In-App Release Notes Banner - A banner message within the application links you directly to these release notes to help you learn what's new in the latest version. [sampleDash] — **SM Starter+**
- Search for samples by storage location. Box names and labels are now indexed to make it easier to find storage in larger systems. [search] — **SM Starter+**
- Only an administrator can delete a storage system that contains samples. Non-admin users with permission to delete storage must first remove the samples from that storage in order to be able to delete it. [freezerDetails] — **SM Starter+**
- ELN Signing Authentication - Electronic Lab Notebook enhancements: [elnExport] — **SM Professional+**

#### Release 23.12, December 2023

- Samples can be moved to multiple storage locations at once. [freezerMove] — **SM Starter+**
- New storage units can be created when samples are added to storage. [createFreezer] — **SM Starter+**
- Notebook Table of Contents - The table of contents for a notebook now includes headings and day markers from within document entries. [elnCreate] — **SM Professional+**
- Workflow templates can now have editable assay tasks allowing common workflow procedures to have flexibility of the actual assay data needed. [jobTemplate] — **SM Professional+**
- Units Preserved on Grid Update - When samples or aliquots are updated via the grid, the units will be correctly maintained at their set values. This addresses an issue in earlier releases and is also fixed in the 23.11.2 maintenance release. — **SM Starter+**
- Molecule Property Calculator - The Molecule physical property calculator offers additional selection options and improved accuracy and ease of use. [moleculeCalc] — **LIMS Enterprise+**

#### Release 23.11, November 2023

- Moving samples between storage locations now uses the same intuitive interface as adding samples to new locations. [freezerMove] — **SM Starter+**
- Sample grids now include a direct menu option to "Move Samples in Storage". [gridBasics] — **SM Starter+**
- Standard assay designs can be renamed. [manageAssayDesign] — **SM Professional+**
- Users can share saved custom grid views with other users. [customViews] — **SM Starter+**
- Authorized users no longer need to navigate to the home project to add, edit, and delete data structures including Sample Types, Registry Source Types, Assay Designs, and Storage. Changes can be made from within a subproject, but still apply to the structures in the home project. [folders] — **SM Professional+**
- Always-Visible Save and Cancel - The interface has changed so that the 'cancel' and 'save' buttons are always visible to the user in the browser. [createSampleType] — **SM Starter+**
- Update Mixtures and Batch definitions using the Recipe API. [regBatches] — **LIMS Enterprise+**

#### Release 23.10, October 2023

- Adding Samples to Storage is easier with preselection of a previously used location, and the ability to select which direction to add new samples: top to bottom or left to right, the default. [storeFreezer] — **SM Starter+**
- Import Aliases as Default Parent Fields - When Samples or Sources are created manually, any import aliases that exist will be included as parent fields by default, making it easier to set up expected lineage relationships. [createSamples] — **SM Starter+**
- Grid settings are now persistent when you leave and return to a grid, including which filters, sorts, and paging settings you were using previously. [gridBasics] — **SM Starter+**
- Header menus have been reconfigured to make it easier to find administration, settings, and help functions throughout the application. [sampleDash] — **SM Starter+**
- Panels of details for Sample Types, Sources, Storage, etc. are now collapsed and available via hover, putting the focus on the data grid itself. [viewSampleSets] — **SM Starter+**

#### Release 23.9, September 2023

- View all samples of all types from a new dashboard button. [viewSampleSets] — **SM Starter+**
- Storage Location Preview on Add - When adding samples to storage, users will see more information about the target storage location including a layout preview for boxes or plates. [storeFreezer] — **SM Starter+**
- Longer storage location paths will be 'summarized' for clearer display in some parts of the application. [freezerLocation] — **SM Starter+**
- Charts Above Grids - Charts, when available, are now rendered above grids instead of within a popup window. [bioCharts] — **SM Starter+**
- Naming patterns can now incorporate a sampleCount or rootSampleCount element. [sampleIDs] — **SM Starter+**

#### Release 23.8, August 2023

- Sources can have lineage relationships, enabling the representation of more use cases. [createSources] — **SM Starter+**
- Two new calculated columns provide the "Available" aliquot count and amount, based on the setting of the sample's status. [aliquots] — **SM Starter+**
- Sample Amount Update on Discard - The amount of a sample can be updated easily during discard from storage. [manageStored] — **SM Starter+**
- Customize the display of date/time values on an application wide basis. [dateFormats] — **SM Starter+**
- Aliquot Naming Pattern Display - The aliquot naming pattern will be shown in the UI when creating or editing a sample type. [createSampleType] — **SM Starter+**
- Increased Box Size Support - The allowable box size for storage units has been increased to accommodate common slide boxes with up to 50 rows. [manageUnits] — **SM Starter+**
- Options for saving a custom grid view are clearer. [customViews] — **SM Starter+**

#### Release 23.7, July 2023

- Define locations for storage systems within the app. [freezerLocation] — **SM Starter+**
- Create new freezer hierarchy during sample import. [importSamples] — **SM Starter+**
- Import & update samples across multiple sample types from a single file. [importSamples] — **SM Starter+**
- Administrators have the ability to do the actions of the Storage Editor role. [permissionLevels] — **SM Starter+**
- Improved options for bulk populating editable grids, including better "drag-fill" behavior and multi-cell cut and paste. (docs | docs) — **SM Starter+**
- rootSampleCount Token Behavior - The rootSampleCount naming pattern token increments for every non-aliquot sample added to the system. [sampleIDs] — **SM Starter+**
- Enhanced security by removing access or identifiers to data in different projects in lineage, sample timeline and ELNs. [crossFolder] — **SM Professional+**
- ELN Reference and Autocomplete - ELN Improvements: — **SM Professional+**
- Move Assay Runs and Notebooks between Projects. (docs | docs) — **SM Professional+**

#### Release 23.6, June 2023

- See an indicator in the UI when a sample is expired. [sampleExpiration] — **SM Starter+**
- Sample Type Auto-Selection - On Sample grids in Picklists, Workflows & Source Details pages, when only one Sample Type is included in a grid that supports multiple Sample Types, default to that tab instead of to the general "All Samples" tab. [gridBasics] — **SM Starter+**
- Track the edit history of Notebooks. [elnCreate] — **SM Professional+**
- Control which data structures and storage systems are visible in which Projects. [folders] — **SM Professional+**
- Move Sources Between Projects - Move Sources between Projects. [crossFolder] — **SM Professional+**
- Project menu includes quick links to settings and the dashboard for that Project. [folders] — **SM Professional+**

#### Release 23.5, May 2023

- Move Samples Between Projects - Move Samples between Projects. [crossFolder] — **SM Professional+**
- Assay Results grids can be modified to show who created and/or modified individual result rows and when. [manageAssayData] — **SM Professional+**
- BarTender templates can only be defined in the home Project. [setupBarTender] — **SM Professional+**
- ELN Improvements - Pagination controls are available at the bottom of the ELN dashboard. [elnDash] — **SM Professional+**
- My Tracked Jobs - A new "My Tracked Jobs" option helps users follow workflow tasks of interest, even when they are not assigned tasks. [manageQueue] — **SM Professional+**

#### Release 23.4, April 2023

- Add the sample amount during sample registration to better align with laboratory processes. (docs | docs) — **SM Starter+**
- Use the Sample Finder to find samples by sample properties, as well as by parent and source properties. [sampleFinder] — **SM Starter+**
- Built in Sample Finder reports help you track expiring samples and those with low aliquot counts. [sampleReports] — **SM Starter+**
- Text search result pages are more responsive and easier to use. [search] — **SM Starter+**
- Administrators can specify a default BarTender template. [setupBarTender] — **SM Starter+**
- ELN Improvements - View archived notebooks. [elnCreate] — **SM Professional+**
- Sample Status values can only be defined in the home project. Existing unused custom status values in sub-projects will be deleted and if you were using projects and custom status values prior to this upgrade, you may need to contact us for assistance. [folders] — **SM Professional+**
- For Professional Edition users of Projects, Sample Statuses defined in sub-projects should be migrated to the home project. With this release, unused Sample Status values will be removed and must be added again manually. Contact your Account Manager if you need help with this migration. — **SM Professional+**
- Molecular Physical Property Calculator is available for confirming and updating Molecule variations. [moleculeCalc] — **LIMS Enterprise+**
- Lineage relationships among custom registry sources can be represented. [editBioregistry] — **LIMS Enterprise+**
- Users of the Enterprise Edition can track amounts and units for raw materials and mixture batches. [regBatches] — **LIMS Enterprise+**

#### Release 23.3, March 2023

- Samples can have expiration dates, making it possible to track expiring inventories. [sampleExpiration] — **SM Starter+**
- User profile details will be shown when a username is clicked from grids. [manageUsers] — **SM Starter+**
- Administrators can see the which version of Sample Manager they are running. [manageUsers] — **SM Starter+**
- ELN Panel and Link Improvements - ELN Improvements: — **SM Professional+**
- Potential Backwards Compatibility Issue - In 23.3, we added the materialExpDate field to support expiration dates for all samples. If you happen to have a custom field by that name, you should rename it prior to upgrading to avoid loss of data in that field. — **LIMS Enterprise+**

#### Release 23.2, February 2023

- Clearly capture why any data is deleted with user comments upon deletion. (docs | docs) — **SM Starter+**
- Data update (or merge) via file has moved to the "Edit" menu of a grid. Importing from file on the "Add" menu is only for adding new data rows. (docs | docs | docs) — **SM Starter+**
- Use grid customization after finding samples by ID or barcode, making it easier to use samples of interest. [sampleSearch] — **SM Starter+**
- Electronic Lab Notebooks now include a full review and signing event history in the exported PDF, with a consistent footer and entries beginning on the second page of the PDF. [elnExport] — **SM Professional+**
- Projects in the Professional Edition of Sample Manager are more usable and flexible. — **SM Professional+**
- Protein Sequences can be reclassified and reannotated in cases where the original classification was incorrect or the system has evolved. [reclassify] — **LIMS Enterprise+**
- Lookup views allow you to customize what users will see when selecting a value for a lookup field. [grids] — **LIMS Enterprise+**

#### Release 23.1, January 2023

- Storage management has been generalized to clearly support non-freezer types of sample storage. [smFreezer] — **SM Starter+**
- Samples will be added to storage in the order they appear in the selection grid. [storeFreezer] — **SM Starter+**
- Multiple BarTender Label Templates - Curate multiple BarTender label templates, so that users can easily select the appropriate format when printing. [setupBarTender] — **SM Starter+**
- ELN Signing Authentication - Electronic Lab Notebook enhancements: [elnExport] — **SM Professional+**
- Updated Main Menu - An updated main menu making it easier to access resources across projects. [folders] — **SM Professional+**
- Easily update Assay Run-level fields in bulk instead of one run at a time. [manageAssayData] — **SM Professional+**
- Heatmap and card views of the bioregistry, sample types, and assays have been removed. — **LIMS Enterprise+**
- Registry Source Types Terminology - The term "Registry Source Types" is now used for categories of entity in the Bioregistry. [registration] — **LIMS Enterprise+**

#### Release 22.12, December 2022

- Multi-Project Professional Edition - The Professional Edition supports multiple Sample Manager Projects. [folders] — **SM Professional+**
- Improved interface for assay design and data import. (docs | docs) [bioProject] — **SM Professional+**
- From assay results, select sample ID to examine derivatives of those samples in Sample Finder. [manageAssayData] — **SM Professional+**
- Projects were added to the Professional Edition of Sample Manager, making this a common feature shared with other tiers. — **LIMS Enterprise+**

#### Release 22.11, November 2022

- Add samples to multiple freezer storage locations in a single step. [storeFreezer] — **SM Starter+**
- Improvements in the Storage Dashboard to show all samples in storage and recent batches added by date. [manageFreezer] — **SM Starter+**
- View all assay results for samples in a tabbed grid displaying multiple sample types. [manageAssayData] — **SM Professional+**
- ELN improvements to make editing and printing easier with a table of contents highlighting all notebook entries and fixed width entry layout, plus new formatting symbols and undo/redo options. [elnCreate] — **SM Professional+**
- New role available - Workflow Editor, granting the ability to create and edit workflow jobs and picklists. [permissionLevels] — **SM Professional+**
- Notebook review can be assigned to a user group, supporting team workload balancing. [elnCreate] — **SM Professional+**
- Improvements in the interface for managing Projects. [bioProject] — **LIMS Enterprise+**
- New Biologics Documentation - New documentation: — **LIMS Enterprise+**

#### Release 22.10, October 2022

- Use sample ancestors in naming patterns, making it possible to create common name stems based on the history of a sample. [sampleIDs] — **SM Starter+**
- Additional entry points to Sample Finder. Select a source or parent and open all related samples in the Sample Finder. (docs | docs) — **SM Starter+**
- New role available - Editor without Delete. Users with this role can read, insert, and update information but cannot delete it. [permissionLevels] — **SM Starter+**
- Group management allowing permissions to be managed at the group level instead of always individually. (docs | docs) — **SM Starter+**
- Assay Results in Sample Finder - With the Professional Edition, use assay results as a filter in the sample finder helping you find samples based on characteristics like cell viability. [sampleFinder] — **SM Professional+**
- Assay run properties can be edited in bulk. [manageAssayData] — **SM Professional+**
- Improved interface for creating and managing Projects in Biologics. [bioProject] — **LIMS Enterprise+**

#### Release 22.9, September 2022

- Searchable, filterable, standardized user-defined fields on workflow enable teams to create structured requests for work, define important billing codes for projects and eliminate the need for untracked email communication. [jobTemplate] — **SM Professional+**
- Storage grids and sample search results now show multiple tabs for different sample types. With this improvement, you can better understand and work with samples from anywhere in the application. (docs | docs | docs) — **SM Starter+**
- Pinned Sample ID Column - The leftmost column of sample data, typically the Sample ID, is always shown as you examine wide datasets, making it easy to remember what sample's data you were looking at. [gridBasics] — **SM Starter+**
- By prohibiting sample deletion when they are referenced in an ELN, Sample Manager helps you further protect the integrity of your data. [viewSampleSets] — **SM Starter+**
- Easily capture amendments to signed Notebooks when a discrepancy is detected to ensure the highest quality entries and data capture, tracking the events for integrity. [elnAmend] — **SM Professional+**
- Sample-Linked Notebooks - When exploring a Sample of interest, you can easily find and review any associated notebooks. [viewSampleSets] — **SM Professional+**
- Media-Linked Notebooks - When exploring Media of interest, you can easily find and review any associated Notebooks from a panel on the Overview tab. [bioMedia] — **LIMS Enterprise+**

#### Release 22.8, August 2022

- Aliquots can have fields that are not inherited from the parent sample. Administrators can control which parent sample fields are inherited and which can be set independently for the sample and aliquot. [createSampleType] — **SM Starter+**
- Drag within editable grids to quickly populate fields with matching strings or number sequences. [gridBasics] — **SM Starter+**
- Excel Export Tab Summary - When exporting a multi-tabbed grid to Excel, see sample counts and which view will be used for each tab. [gridBasics] — **SM Starter+**
- Search for data across projects in Biologics. [search] — **LIMS Enterprise+**

#### Release 22.7, July 2022

- ELN (Electronic Lab Notebook) is designed to help scientists efficiently document their experiments and collaborate. This data-connected ELN is seamlessly integrated with other laboratory data in the application, including lab samples, assay data and other registered data. [sampleELN] — **SM Starter+**
- Make manifest creation and reporting easier by exporting sample types across tabs into a multi tabbed spreadsheet. [gridBasics] — **SM Starter+**
- All users can now create their own named custom view of grids for optimal viewing of the data they care about. Administrators can customize the default view for everyone. [customViews] — **SM Starter+**
- Export data from an 'edit in grid' panel, particularly useful in assay data imports for partially populating a data 'template'. (docs | docs) — **SM Starter+**
- Newly surfaced Picklists allow individuals and teams to create sharable sample lists for easy shipping manifest creation and capturing a daily work list of samples. [sampleDash] — **SM Starter+**
- Updated main dashboard providing quick access to notebooks in the Professional Edition of Sample Manager. [sampleDash] — **SM Starter+**
- Samples can now be renamed in the case of a mistake; all changes are recorded in the audit log and sample ID uniqueness is still required. [viewSampleSets] — **SM Starter+**
- Pinned Column Header Row - The column header row is 'pinned' so that it remains visible as you scroll through your data. [gridBasics] — **SM Starter+**
- Deleting samples from the system entirely when necessary is now available from more places, including the Samples tab for a Source. [viewSourceTypes] — **SM Starter+**
- Biologics subfolders are now called 'Projects'; the ability to categorize notebooks now uses the term 'tags' instead of 'projects'. [elnTags] — **LIMS Enterprise+**

#### Release 22.6, June 2022

- Save time looking for samples and create standard sample reports by saving your Sample Finder searches to access later. [sampleFinder] — **SM Starter+**
- Support for commas in Sample and Source names. [sampleIDs] — **SM Starter+**
- Administrators will see a warning when the number of users approaches the limit for your installation. [manageUsers] — **SM Starter+**
- Compound Bioregistry type supports Simplified Molecular Input Line Entry System (SMILES) strings, their associated 2D structures, and calculated physical properties. [bioCompounds] — **LIMS Enterprise+**
- Define and edit Bioregistry entity lineage. [editEntity] — **LIMS Enterprise+**
- Bioregistry entities include a "Common Name" field. [createEntity] — **LIMS Enterprise+**

#### Release 22.5, May 2022

- Updated grid menus - Sample grids now help you work smarter (not harder) by highlighting actions you can perform on samples and grouping them to make them easier to discover and use. [gridBasics] — **SM Starter+**
- filtering and enhanced column header options for more intuitive sorting, searching and filtering. [gridBasics] — **SM Starter+**
- Sort and filter based on 'lineage metadata', bringing ancestor information (Source and Parent details) into sample grids [deriveSamples] — **SM Starter+**
- Rename Source Types and Sample Types to support flexibility as your needs evolve. Names/SampleIDs of existing samples and sources will not be changed. [createSampleType] — **SM Starter+**
- Descriptions for workflow tasks and jobs can be multi-line when you use Shift-Enter to add a newline. [startJob] — **SM Starter+**

#### Release 22.4, April 2022

- Multiple Filter Expressions in Sample Finder - In the Sample Finder, apply multiple filtering expressions to a given column of a parent or source type. [sampleFinder] — **SM Starter+**
- Download Templates from More Locations - Download templates from more places, making it easier to import samples, sources, and assay data from files. [dataImport] — **SM Starter+**

#### Release 22.3, March 2022

- Sample Finder - Find samples based on source and parent properties, giving users the flexibility to locate samples based on relationships and lineage details. [sampleFinder] — **SM Starter+**
- Redesigned main dashboard featuring storage information and prioritizing what users use most. [sampleDash] — **SM Starter+**
- Updated freezer overview panel and dashboards present storage summary details. [manageFreezer] — **SM Starter+**
- Available freezer capacity is shown when navigating freezer hierarchies to store, move, and manage samples. (docs | docs) — **SM Starter+**
- Storage labels and descriptions give users more ways to identify their samples and storage units. [createFreezer] — **SM Starter+**
- Mixture import improvement - choose between replacing or appending ingredients added in bulk. [media] — **LIMS Enterprise+**

#### Release 22.2, February 2022

- Storage Editor and Storage Designer roles, allowing admins to assign different users the ability to manage freezer storage and manage sample and assay definitions. [freezerRoles] — **SM Starter+**
- Multiple permission roles can be assigned to a new user at once. [manageUsers] — **SM Starter+**
- Sample Type Insights panel summarizes storage, status, etc. for all samples of a type. [viewSampleSets] — **SM Starter+**
- Sample Status options are shown in a hover legend for easy reference. [sampleStatus] — **SM Starter+**
- Consumed and Discarded Status Sync - When a sample is marked as "Consumed", the user will be prompted to also change it's storage status to "Discarded" (and vice versa). (docs | docs) — **SM Starter+**
- User-defined barcodes in integer fields can also be included in sample definitions and search-by-barcode results. [uniqueStorageIds] — **SM Starter+**
- Search menu includes quick links to search by barcode or sample ID. [sampleSearch] — **SM Starter+**
- See and set the value of the "genId" counter for naming patterns. [sampleIDs] — **SM Starter+**

#### Release 22.1, January 2022

- Text Choice data type lets admins define a set of expected text values for a field. — **SM Starter+**
- Naming patterns will be validated during sample type definition. [sampleIDs] — **SM Starter+**
- Editable grids include visual indication when a field offers dropdown choices. [editSamples] — **SM Starter+**
- Add freezer storage units in bulk. [createFreezer] — **SM Starter+**
- User-defined barcodes can be included in Sample Type definitions as text fields and are scanned when searching samples by barcode. (docs | docs) [uniqueStorageIds] — **SM Starter+**
- Digit-Only Sample Name Warning - If any of your Sample Types include samples with only strings of digits as names, these could have overlapped with the "rowIDs" of other samples, producing unintended results or lineages. With this release, such ambiguities will be resolved by assuming that a sample name has been provided. [sampleIDs] — **SM Starter+**

#### Release 21.12, December 2021

- Sample Count by Status graph on the main dashboard now shows samples by type (in bars) and status (using color coding). Click through to a grid of the samples represented by each block. [sampleStatus] — **SM Starter+**
- Grids that may display multiple Sample Types, such as picklists, workflow tasks, etc. offer tabs per sample type, plus a consolidated list of all samples. This enables actions such as bulk sample editing from mixed sample-type grids. (picklists | tasks | sources) — **SM Starter+**
- Improved display of color coded sample status values. [sampleStatus] — **SM Starter+**
- Include a comment when updating storage amounts or freeze/thaw counts. [manageStored] — **SM Starter+**
- Workflow tasks involving assays will prepopulate a grid with the samples assigned to the job, simplifying assay data entry. [completeTasks] — **SM Starter+**
- Freezer Management is added to Biologics LIMS — **LIMS Enterprise+**

#### Release 21.11, November 2021

- Archive an assay design so that new data is disallowed, but historic data can be viewed. [manageAssayDesign] — **SM Starter+**
- Manage sample status, including but not limited to - available, consumed, locked. [sampleStatus] — **SM Starter+**
- Incorporate lineage lookups into sample naming patterns [sampleIDs] — **SM Starter+**
- Assign a prefix to be included in the names of all Samples and Sources created in a given project. Removed in version 22.12. — **SM Starter+**
- Prevent users from creating their own IDs/Names in order to maintain consistency using defined naming patterns [smPrefix] — **SM Starter+**
- Apply a container specific prefix to all bioregistry entity and sample naming patterns. [bioProject] — **LIMS Enterprise+**

#### Release 21.10, October 2021

- Customizable Aliquot Naming - Customize the aliquot naming pattern. [aliquots] — **SM Starter+**
- Sample names can incorporate field-based counters using :withCounter syntax. [sampleIDs] — **SM Starter+**
- Record the physical location of freezers you manage, making it easier to find samples across distributed sites. [freezerLocation] — **SM Starter+**
- Manage all samples and aliquots created from a source more easily. [viewSourceTypes] — **SM Starter+**
- Comments on workflow job tasks can be formatted in markdown and multithreaded. [completeTasks] — **SM Starter+**
- Redesigned Job Tasks Page - Redesigned job tasks page. [completeTasks] — **SM Starter+**
- Customize the definitions of data classes (both bioregistry and media types) within the application. [editBioregistry] — **LIMS Enterprise+**

#### Release 21.9, September 2021

- Edit sources and parents of samples in bulk — **SM Starter+**
- Customize the names of entities in the bioregistry [createEntity] — **LIMS Enterprise+**

#### Release 21.8, August 2021

- Aliquot views available at the parent sample level. See aggregate volume and count of aliquots and sub-aliquots. — **SM Starter+**
- Find Samples using barcodes or sample IDs — **SM Starter+**
- Import aliases for sample Sources and Parents are shown in the Sample Type details and included in downloaded templates. — **SM Starter+**
- Improved interface for managing workflow jobs and templates. [bioProject] — **SM Starter+**

#### Release 21.7, July 2021

- Sample actions can be initiated from Freezer views — **SM Starter+**
- Experiment Mechanism Removed - Removal of the previous "Experiment" mechanism. Use workflow jobs instead. [workflow] — **LIMS Enterprise+**

#### Release 21.6, June 2021

- Aliquots of samples singly or in bulk — **SM Starter+**
- Picklists of samples to simplify operations on groups of samples — **SM Starter+**
- Track movement of storage units within a freezer, or to another freezer — **SM Starter+**
- Minor change in freezer editing behavior that the hierarchy is initially collapsed. — **SM Starter+**

#### Release 21.5, May 2021

- Copy a Freezer definition — **SM Starter+**
- Samples and Sources can include images and other file attachments — **SM Starter+**
- Nucleotide and Protein Sequence values can be hidden from users who have access to read other data in the system. [biologicsPHI] — **LIMS Enterprise+**

#### Release 21.4, April 2021

- Barcode generation for Samples — **SM Starter+**
- Reserved Fields Excluded from Inference - When inferring fields to create Sources, Sample Types, and Assay Designs from a spreadsheet, any "reserved" fields present will not be shown in the inferral, simplifying the creation process — **SM Starter+**
- Unrecognized Fields Ignored on Import - When importing data, any unrecognized fields will be ignored and a banner will be shown — **SM Starter+**
- My Queue Renamed - On the main menu, "My Assigned Work" has been renamed "My Queue" — **SM Starter+**
- Specialty Assays can now be defined and integrated, in addition to Standard Assays [setUpAssays] — **LIMS Enterprise+**
- Creation of Raw Materials in the application uses a consistent interface with other sample type creation [bioMedia] — **LIMS Enterprise+**

#### Release 21.3, March 2021

- Tube Rack type of freezer storage unit has been added — **SM Starter+**
- Derive samples from one or more parent samples — **SM Starter+**
- Field Editor Summary View - The field editor offers a new "Summary" view — **SM Starter+**
- Biologics LIMS begins using the same user interface as Sample Manager. — **LIMS Enterprise+**
- Release notes for this and other versions prior to this change can be found in the documentation archives . — **LIMS Enterprise+**

#### Release 21.2, February 2021

- Field Editor Bulk Delete and Export - The field editor now includes checkboxes to enable deletion of multiple fields and export of subsets of fields. — **SM Starter+**
- Background Import Enhancements - Background Import: — **SM Starter+**

#### Release 21.1, January 2021

- Freezer Management - Freezer Management — **SM Starter+**

#### Release 20.12, December 2020

- Detailed audit logging now shows only what has changed when data is updated. — **SM Starter+**

#### Release 20.11, November 2020

- Batching of creating samples and sources, enabling selection of "just created" items. — **SM Starter+**

#### Release 20.10, October 2020

- Integration with BarTender to print labels. — **SM Starter+**

#### Release 20.9, September 2020

- Label colors are shown in the samples section of the main dashboard. — **SM Starter+**
- Storage Menu Access Preview - In anticipation of future support for Freezer Management, underlying functionality like the ability to access storage locations from the main menu have been added. — **SM Starter+**

#### Release 20.8, August 2020

- Sample Types can have custom Label Color assignments to help users differentiate them. [createSampleType] — **SM Starter+**
- Sample Storage Location Preview - In anticipation of future support for Freezer Management, underlying functionality like the ability to see the storage location of a sample has been added. These facilities are not yet visible in the application interface. — **SM Starter+**

#### Release 20.7, July 2020

- Improved search experience. Filter and refine search results. [search] — **SM Starter+**

#### Release 20.6, June 2020

- Bug fixes and small improvements — **SM Starter+**

#### Release 20.5, May 2020

- Use Sample Timelines to track all events involving a given sample. — **SM Starter+**
- Detailed audit logging has been improved for samples, under the new heading "Sample Timeline Events." — **SM Starter+**
- Sample Types can be created by inferring fields from a file, or by defining fields manually. Source types offer the same convenience. [sampleDash] — **SM Starter+**
- Editing of sample parents is now available. — **SM Starter+**
- Source Alias Columns in Sample Types - The definition of Sample Types can now include "Source Alias" columns, similar to parent aliases already available. — **SM Starter+**

#### Release 20.4, April 2020

- Unified Sample Type Creation Page - The creation interface for Sample Types has been merged to a single page showing both properties and fields. This makes it easier to create naming expressions that use fields in your Sample Type. — **SM Starter+**
- Define Sources for Samples - Define Sources for your samples. The source of a sample could be an individual or a cell line or a lab. Tracking metadata about the source of samples, both biological and physical, can unlock new insights. — **SM Starter+**

#### Release 20.3, March 2020

- Samples can be added to a workflow job during job creation. You no longer need to start a job after selecting samples of interest, but can add or update the samples directly within the job editing interface. — **SM Starter+**
- Removing unnecessary fields is easier with an icon shown in the collapsed field view. — **SM Starter+**
- LabKey Sample Manager is Launched! — **SM Starter+**

#### Release 17.1, March 2017

- Biologics LIMS is Launched! — **LIMS Enterprise+**

## 6. Cross-cutting findings, and the requirements they generate

### 6.1 The negatives, which are the most reusable result

These were established by searching the full text of all 60 server
release-notes pages and all 83 LIMS release sections. A zero here is a real
zero over nineteen years of release notes, not an absence of evidence.

| Term | Occurrences | What it means |
| --- | --- | --- |
| `hash` | **0** in 60 server pages | LabKey has never shipped a hash-chained or otherwise cryptographically linked audit trail. ADR-0003 has no prior art to follow and no compatibility to preserve. |
| `tamper` | **0** in 60 server pages | Neither product claims tamper-evidence. |
| `21 CFR`, `Part 11`, `GxP`, `GMP` | **0** in 60 server pages; **1** in 83 LIMS sections | The single occurrence (LIMS 26.7.3, July 2026) is a *warning* that skipping SAML re-authentication *"may affect 21 CFR Part 11 eSignature requirements"*. LabKey does not market Part 11 compliance in its release notes at all. Any OSM claim in this area is OSM's own. |
| `row-level security` | **1** in 60 server pages | Server 26.7, and it means *"container and row-level permissions"* — LabKey's container and dataset permission model, **not** PostgreSQL row-level security. FR-012's RLS remains something neither product has. |
| storage check-in / check-out | **1** in 60 server pages — the phrase *"Check samples in and out of storage"* in 21.3, and nothing else. **2** releases on the LIMS page: the 26.5 workflow storage actions and the 25.7.8 `CheckedOut` column. | The most central operation in a LIMS is named in three releases across nineteen years, and **never once with concurrency, conflict or atomicity semantics**. FR-029's *"atomic, 409 on conflict"* is unlike anything documented on either side. |
| ZPL, Zebra, or any direct label-printer protocol | **0** everywhere | BarTender is the whole label story (server 20.11 / LIMS 20.10). §15's ZPL open question has no prior art, as `docs/gap-analysis.md` already records. |

### 6.2 The paywall moved, and it moved outward

The survey makes the direction of travel unambiguous. Community Edition **lost**
capability in the sample domain over this period:

| Release | Removed from Community Edition |
| --- | --- |
| 21.3 (Mar 2021) | **Specimen Repository** — *"removed from all standard distributions (Community, Starter, Professional, and Enterprise)"*, retained only for existing premium clients. |
| 21.3 | Microsoft SQL Server and all non-PostgreSQL external data sources (BigIron → premium). |
| 21.7 (Jul 2021) | **Specialty Assays** — ELISA, ELISpot, NAb, Luminex, Flow. Standard Assay retained. |
| 22.3 (Mar 2022) | Panorama; Mass Spectrometry (MS2). |
| 25.3 (Mar 2025) | **FreezerPro integration**; **SampleMinded integration**. |
| 25.11 (Nov 2025) | Advanced folder-archive import options (selective object import, multi-folder application). |

Against that, what CE **gained** in the same period is almost entirely
audit, security and API hygiene — 25.11's forced detailed audit on samples and
sources, 26.3's per-folder "See Audit Log Events" role and grid-view audit,
26.7's role-restricted API keys. **These are precisely the things the OSM
publish bridge depends on, and none of them is a sample-management feature.**
That is a coherent picture, and it is the one ADR-0001 assumes: LabKey CE is
converging on being a good, well-audited data platform, and it is not
converging on being a LIMS.

### 6.3 New requirements derived from this survey

Nineteen. Each is a capability LabKey demonstrably ships that the OSM
specification does not cover, and that belongs in OSM's scope on the reasoning
given. They use the repository's existing ID scheme and continue its numbering
(`FR-068`…`FR-081`, `NFR-008`, `CON-015`…`CON-018`). Each carries a `spec`-kind
traceability edge to the exact URL it came from:

```bash
tools/memory.py show FR-068
tools/memory.py query "SELECT req_id, artifact_ref FROM traceability
                       WHERE artifact_kind='spec' AND artifact_ref LIKE 'https://%'"
```

| ID | Title | Iteration | Derived from |
| --- | --- | --- | --- |
| FR-068 | Aliquot fields that are not inherited from the parent | I1 | server 22.11; LIMS 22.8 |
| FR-069 | Sample expiry date, expiry indicator and expiring-sample report | I1 | server 23.3, 23.7; LIMS 23.3, 23.6 |
| FR-070 | Reason for change on a mutation, configurably required per operation class | I0 | server 24.3, 24.7; LIMS 24.2, 24.4, 25.6, 26.7 |
| FR-071 | Identifying fields — a bounded set of fields shown wherever a sample is referenced | I1 | LIMS 24.11, 24.12, 25.10, 26.3, 26.7.3 |
| FR-072 | Amount and unit validated as a pair; amount may not be negative | I1 | LIMS 25.10, 25.12 |
| FR-073 | Check-out recorded as a queryable, timestamped attribute of the sample | I2 | LIMS 25.7.8 |
| FR-074 | Storage units identified by their own barcode, unique across the deployment | I2 | LIMS 26.7 |
| FR-075 | Storage and lineage operations available as workflow job tasks | I3 | LIMS 26.4, 26.5, 26.6, 26.9 |
| FR-076 | Lineage relationships markable as required on a sample type | I1 | LIMS 24.10 |
| FR-077 | ELN recall and return-for-changes, with a review timeline | I4 | server 24.7; LIMS 24.5, 25.11 |
| FR-078 | Signature attestation text configurable per institution | I4 | server 24.7; LIMS 24.6 |
| FR-079 | Sample status usable as a filter on the lineage graph | I5 | LIMS 26.7 |
| FR-080 | Design authority separable from edit authority | I0 | server 22.3, 24.7; LIMS 22.2 |
| FR-081 | Archive as an alternative to deletion for types, designs and templates | I1 | server 21.11; LIMS 21.11, 24.11, 26.8 |
| NFR-008 | Box geometry supported to at least 50 rows by 50 columns | I2 | server 23.11; LIMS 23.8 |
| CON-015 | Lineage and timeline must not leak identifiers across a permission boundary | I5 | server 23.7; LIMS 26.2 |
| CON-016 | Publishing targets the container it writes into; cross-folder import is unavailable | I6 | LIMS 26.7 |
| CON-017 | The bridge must not lower LabKey's audit level, and must not assume it can | I6 | server 25.11; LIMS 25.9 |
| CON-018 | The bridge pins the LabKey version it targets and re-verifies on upgrade | I6 | server 26.3; LIMS 24.10 |

CON-018 deserves its reasoning stated. In a single eighteen-month window LabKey
moved workflow tables **out of the `sampleManagement` schema into a new
`workflow` schema** (26.1/26.3), renamed the storage removal action from
**"Discard" to "Remove"** and the subcontainer from **"Project" to "Folder"**
(LIMS 24.10), removed **cross-folder import** (26.7), and removed the **Derive
Samples** UI (26.7). None of these is announced as a breaking API change, and
OSM's specification §16 names LabKey objects by their current vocabulary. A
bridge that does not pin and re-verify will break quietly.

### 6.4 What this survey does *not* establish

Nothing here has been checked against `/root/scicore` or the running server.
In particular, all of the following are **open questions, not findings**:

- Whether `experiment-derive.api` still functions in 26.7 now that the Derive
  Samples button is gone.
- Whether the 25.11 audit-level floor actually rejects `auditBehavior: NONE`
  from a client API call, or merely ignores it.
- Whether the 22.11 Storage API (Java/JS/Python/R) does anything in CE, given
  that `InventoryService.get()` returns `null`.
- Whether the 23.11 per-field uniqueness constraint is enforced by a database
  constraint or by application code, which decides whether the bridge can rely
  on it for `osm_id`.
- Whether the LIMS MCP Server (26.4) and the SDMS MCP Server (26.3) are one
  subsystem or two.

PR-039 exists to close these against the running server and record the results
as verifications. Until then they stay `doc`-grade.

## 7. Flagged as questionable scope

Deliberately **not** turned into requirements. Each is a real LabKey capability;
each is listed here so the decision to exclude it is visible and reversible
rather than silent.

| LabKey capability | Where | Why it is flagged, not adopted |
| --- | --- | --- |
| **Freeze/thaw cycle counting** | server 21.3, 22.3; LIMS 21.12 | A genuine cryobiology need and cheap to add — but the OSM specification never mentions it, and it implies a sample-integrity model (cycle limits, quality impact) that nobody has asked for. **Recommend: ask the specification owner.** |
| **Plate sets, plate campaigns, multi-plate hit selection, liquid-handler instructions** | LIMS 24.11–25.3, LIMS Enterprise+ | An entire domain — plate layout, dilution series, outlier exclusion. OSM §1 explicitly excludes primary analysis. **Recommend: out of scope.** |
| **Media, recipes, ingredients, raw materials, media-batch aliquoting** | server 17.2, 18.1, 18.2, 22.11 | Biologics manufacturing, not sample custody. `docs/gap-analysis.md` already treats `recipe` as a premium module OSM does not mirror. **Recommend: out of scope**, but note §17.1's `P-INTAKE` would need extending if a lab ever registers consumables. |
| **Bioregistry: nucleotide/protein sequences, molecules, compounds, SMILES** | server 17.2–26.7; LIMS 26.2, 26.5, 26.8 | Biologics LIMS only. Nothing in the OSM specification touches it. **Recommend: out of scope.** |
| **Access recertification / project review workflow** | server 21.7 | *"Administrators can enforce regular review of project access permissions."* A real control and arguably a compliance requirement — but it is an identity-governance feature, not a sample one, and §11 does not ask for it. **Recommend: defer to an ADR if an auditor asks for it.** |
| **Project locking** | server 21.7 | Same reasoning. Cheap; unspecified. |
| **Saved Sample Finder searches and shipped finder reports** (expiring samples, low aliquot counts) | server 22.7, 23.7 | Very likely wanted in practice. Not specified. FR-039 defines facets, not saved reports. **Recommend: raise as a specification amendment rather than smuggling it into PR-027.** |
| **Clone / copy a freezer definition** | server 21.7; LIMS 21.5 | Convenience over FR-028's hierarchy. Trivial once the hierarchy exists. **Recommend: defer to a follow-on.** |
| **Create the storage hierarchy from the import file** | server 23.7; LIMS 24.9 | Attractive intake shape, but it lets a CSV create physical infrastructure, which cuts against the Storage-admin/Technician role split in §11. **Recommend: explicitly refuse, and say why in the FRD.** |
| **Print a box view for offline use** | server 24.7; LIMS 24.5 | Implies an offline working mode with a reconciliation story OSM has not designed. **Recommend: out of scope until an offline requirement exists.** |
| **Prevent users supplying their own sample IDs** | server 21.11; LIMS 21.11 | A per-sample-type policy flag. Plausibly in scope under FR-023, but it is a policy the specification does not state. **Recommend: confirm with the specification owner.** |
| **Structured user-defined fields on workflow jobs (billing codes, work requests)** | server 22.11; LIMS 22.9 | Turns a job into a request form. §6 does not. **Recommend: out of scope for I3; revisit if the queue is used for intake requests.** |
| **BarTender integration** | server 20.11; LIMS 20.10 | LabKey's only label path, and it is a commercial Windows product. §15 asks for ZPL. **Recommend: do not adopt BarTender; keep §15 open.** |
| **AI-generated SQL / `executeSQL` MCP tool** | server 26.7 | Explicitly forbidden by PRO-009. Listed only so the contrast with LabKey's model is on the record. **Recommend: never.** |
