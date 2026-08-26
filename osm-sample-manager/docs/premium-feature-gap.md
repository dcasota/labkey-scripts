# Premium feature gap: what LabKey withholds from Community Edition

A walk of the LabKey documentation tree, cataloguing every feature LabKey marks
as unavailable in Community Edition, with the edition that provides it and the
page that says so.

Companion to [`docs/gap-analysis.md`](gap-analysis.md), which is the *headline*
and is grounded in source under `/root/scicore`. **This page is `doc`-grade
evidence** (`standards/general/verification.md`): it records what LabKey
*documents*, which is not the same as what LabKey *implements*.
`docs/labkey-ce-ground-truth.md` records five cases where the two diverge, and
§8 of this page adds three more where LabKey's own documentation and its own
pricing page disagree with each other.

Companion also to [`docs/labkey-release-notes-survey.md`](labkey-release-notes-survey.md),
which is the same boundary seen along the time axis: *when* each of these
crossed out of Community Edition.

## Coverage

| | Count |
| --- | --- |
| Unique labkey.org wiki pages fetched | **265** (158 `/Documentation`, 107 `/limshelp`) |
| labkey.com pages fetched | 2 |
| Soft-404s ("This page has no content.") | 17, listed in §18 |
| Hard 404 | 1 (`labkey.com/products-services/labkey-server/sdms-pricing/`) |
| Nav-tree page names discovered on `prevreleases` | 903 |
| Premium / non-Community features catalogued below | **140** |
| Catalogue rows in total | 144 — the other 4 are recorded as Community for contrast |

The crawl was capped at roughly 265 pages against 903 discovered names, and was
steered at the areas this project needs: audit, backup and restore, compliance,
electronic signatures, PHI, folder archives, storage, workflow, sample
management, ELN, notifications, security and authentication, integration, API
and MCP, and search. **The catalogue is therefore thorough in those areas and
deliberately incomplete elsewhere** — assay types, Panorama, studies, flow
cytometry and the developer tree were sampled, not swept.

## How LabKey marks the boundary — three mechanisms, verified in the raw HTML

**1. The page-level badge** on `/Documentation` pages, a `div` at the top of the
wiki body:

```html
<b class="bold">Premium Feature</b> — Available in the Enterprise Edition of LabKey Server.
```

The wording is load-bearing and varies. Five distinct forms were observed:

| Wording | Means |
| --- | --- |
| *"Available with all Premium Editions of LabKey Server"* | Starter and up |
| *"Available in the Professional and Enterprise Editions"* | Professional and up |
| *"Available in the Enterprise Edition"* | Enterprise only |
| *"Also available as an Add-on to the Starter Edition"* | Professional and up, or Starter plus money |
| *"Available upon request with all Premium Editions"* | Premium plus a conversation |

**2. The inline star**, used for individual items inside a list on an otherwise
Community page:

```html
<span class="fa fa-star-o"></span> <FeatureName>: <i class="italic">(Premium Feature)</i>
```

The navigation tree contains **zero** stars — they appear only in page bodies,
so a nav crawl alone finds none of them.

**3. The Sample Manager / LIMS badge**, a blue callout on every `/limshelp`
page:

```html
<b class="bold">Available in:</b> SM Starter · SM Professional · LIMS Starter · LIMS Enterprise · Biologics LIMS
```

The complete observed vocabulary is exactly those five chips. **There is no
"Community" chip anywhere in the `limshelp` wiki.** Every page in that container
documents a paid product. A page may carry a *second* badge lower down for a
feature within it that starts at a higher tier — that is how, for example,
`jobTemplate` documents job templates at SM Professional and template *actions*
at LIMS Starter.

## The one-paragraph answer

**The freezer, the workflow queue, the notebook, the picklist, the finder, the
sample timeline and the sample status UI are not "premium features of LabKey
Server". They are a different product.** They live in the `/limshelp` container,
they are badged against Sample Manager and LIMS editions rather than LabKey
Server editions, and no tier of that product is free. What LabKey Server's own
premium editions add on top is infrastructure — ETL, SSO, PHI enforcement,
compliance logging, external data sources, MCP — not sample management. This
is exactly the boundary ADR-0001 assumes, now confirmed from LabKey's own
documentation rather than inferred from its build files.

---

## 1. Audit and logging

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **Audit Log Maintenance / retention** | Site admins set an audit retention time from 3 months to 7 years; older records are deleted nightly, optionally exported to text first. | *"Premium Feature — Available with all Premium Editions of LabKey Server."* Moved Professional → Starter in 26.3. | <https://www.labkey.org/Documentation/wiki-page.view?name=auditLogMaintenance> | **No — and OSM must not.** ADR-0003 chains audit events; deleting one breaks the chain. FR-062's retention applies to domain data. Recorded here because the *direction* is instructive: LabKey's premium audit feature is the ability to throw audit away. |
| **Compliance Activity Events log** | *"Shows the Terms of Use, IRB, and PHI level declared by users on login."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | No — OSM forbids PHI outright (PRO-001). |
| **Inventory Events log** | *"Events related to freezer and other storage inventory locations, boxes, and items."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | **Yes** — FR-058, PR-017. The storage audit stream does not exist in CE because storage does not. |
| **Notebook events log** | *"Events related to Electronic Lab Notebooks (ELN)."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | **Yes** — FR-060, PR-024–PR-026. |
| **LDAP Sync Events log** | History of LDAP sync events and a summary of changes. | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | No — OSM authenticates via OIDC (FR-013). |
| **Logged select query events** | *"Lists specific columns and identified data relating to explicitly logged queries… as well as the set of PHI-marked columns that were accessed."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | No — no PHI in OSM. |
| **Logged SQL queries** | SQL sent to external datasources configured for explicit logging, with date, container, user and any impersonation. | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=audits> | No — OSM has no external datasource layer. |
| **Compliance logging (query logging)** | Answers *"Which users have seen a given patient's data? What data was viewed by each user?"* — read-access auditing, broader than the write-oriented audit log. | *"Premium Feature — Available in the Enterprise Edition of LabKey Server."* | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceLogging> | **Flagged.** OSM audits every *write* (FR-011). It audits no *read*. For a system holding no PHI that is defensible, but it is a deliberate position and §7 of `gap-analysis.md` should say so. |
| **Export Diagnostic Information** | Site admins download a zip of server diagnostics. *"If you do not see this link, you are not running a premium edition of LabKey Server."* | *"Available with all Premium Editions."* | <https://www.labkey.org/Documentation/wiki-page.view?name=diagnostics> | No — PR-038's runbook covers the same ground. |
| **Application-level audit log views** | Audit history from the app's `Audit Logs` menu, Sample Timeline Events by default, with customisable grids. | *"Available in: SM Starter…"* | <https://www.labkey.org/limshelp/wiki-page.view?name=audits> | **Yes** — FR-026, PR-015. |
| **Require users to provide reasons for actions** | Forces a comment on sample and source edits and deletes, recorded in the audit log. | *"Available in: SM Professional…"* (second badge on the same page) | <https://www.labkey.org/limshelp/wiki-page.view?name=audits> | **Yes — new.** FR-070, PR-040. |
| **Storage activity audit** | Audit of adding and removing samples from storage, plus check-in and check-out. | *"Available in: SM Starter…"* | <https://www.labkey.org/limshelp/wiki-page.view?name=freezerAudit> | **Yes** — FR-058, PR-017. |
| **Sample Timeline** | Graphical per-sample event history. LabKey: it *"can play an important role in tracking chain of custody… and complying with good laboratory practices."* | *"Available in: SM Starter…"* | <https://www.labkey.org/limshelp/wiki-page.view?name=sampleTimeline> | **Yes** — FR-026, PR-015. Note CE *does* record the underlying events (server 20.7); it is the assembled view that is paid for. |

## 2. Backup and restore

**Nothing here is premium, and that is the finding.** `dbBackup`,
`backupRestore`, `backupChecklist`, `backupScenarios` and `enterprisePlan` carry
no badge and no star. LabKey's documented backup story is `pg_dump` and
`pg_restore` guidance, available to everybody.

- <https://www.labkey.org/Documentation/wiki-page.view?name=dbBackup>
- <https://www.labkey.org/Documentation/wiki-page.view?name=backupRestore>

The only edition-linked backup item found anywhere is on labkey.com's Sample
Manager pricing page: **Backup Retention — 90 days (SM Starter) / 180 days
(SM Professional)** (<https://www.labkey.com/products-services/sample-management-software/>).
That is a hosted-service SLA, not a software feature.

**Consequence for OSM.** NFR-006 requires seven-day point-in-time recovery and
PR-038 requires a demonstrated restore. LabKey documents neither PITR nor a
restore drill at any price. **OSM's backup requirement is stricter than the
commercial product's, and there is no prior art to copy — only PostgreSQL's.**

## 3. Compliance and regulatory

Every page in the Compliance tree carries the identical badge: **"Premium
Feature — Available in the Enterprise Edition of LabKey Server."** This is the
top tier; there is no partial access.

| Feature | What it does | URL | OSM must build on CE? |
| --- | --- | --- | --- |
| **Compliance module suite** | *"The Compliance modules help your organization meet a broad array of security and auditing standards, such as FISMA, HIPAA…"* | <https://www.labkey.org/Documentation/wiki-page.view?name=compliance> | Partly — see the rows below. This is the module whose absence makes CE's PHI tags inert (`labkey-ce-ground-truth.md`). |
| **Compliance: Settings** | Account expiration, disable inactive accounts, audit-failure response, FICAM / third-party IdP restriction, session obscuring, project-locking toggle. Admin Console → **Premium Features** → Compliance Settings. | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceSettings> | **Flagged.** *Audit-failure response* — what the server does when it cannot write an audit record — is a real question ADR-0003 does not answer. Everything else is identity governance. |
| **Compliance: Configure PHI Data Handling** | Folder-level Terms of Use, Require Activity/PHI Selection, Require PHI Roles to Access PHI Columns, Query Logging. | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceFolder> | No — PRO-001 excludes PHI from OSM entirely. |
| **Compliance: Terms of Use** | Users must sign Terms of Use before seeing data; different documents per declared activity. | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceTOU> | No — not specified. |
| **Compliance: PHI security roles** | Restricted / Full / Limited PHI Reader. *"Note that these roles are not automatically granted to administrators."* | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceRoles> | No for PHI — but the *principle* that an administrator is not automatically a data reader is worth carrying into PR-006. |
| **Compliance: PHI Report** | *"Shows the PHI level for each column in a given schema. This report is only available when the Compliance module is enabled."* | <https://www.labkey.org/Documentation/wiki-page.view?name=complianceReport> | No. |
| **Compliance: setting PHI levels on fields** | Mark columns Restricted / Full / Limited / Not PHI, via UI or XML. | <https://www.labkey.org/Documentation/wiki-page.view?name=compliancePHI> | No — and note CE *lets you set* these levels while enforcing nothing (see §5). |
| **Project locking and review workflow** | Lock projects against non-admins; enforce periodic permissions review; projects *expire* if a review is missed. | <https://www.labkey.org/Documentation/wiki-page.view?name=projectLock> | **Flagged** — access recertification. Not in the OSM specification. `labkey-release-notes-survey.md` §7 recommends an ADR if an auditor asks. |
| **Limit login attempts** | Lockout after N failed logins. Admin Console → **Premium Features** → Compliance Settings → Login. | <https://www.labkey.org/Documentation/wiki-page.view?name=configDbLogin> | **Yes — but cheap.** Standard practice for PR-006. Note LabKey **moved this to Community Edition in 26.7**, so CE now has it. |
| **Electronic Signatures (21 CFR Part 11)** — LIMS side | *"Configure electronic signatures compliant with FDA 21 CFR Part 11."* | *"Available in: LIMS Enterprise, Biologics LIMS"* — <https://www.labkey.org/limshelp/wiki-page.view?name=enterpriseGov> | **Yes** — FR-038, PR-026. Note the tier: Part 11 signatures sit **two tiers above** the ELN itself. |
| **GDPR compliance** | Guidance page. | <https://www.labkey.org/Documentation/wiki-page.view?name=gdpr> | Unbadged — see §8, ambiguity 2. |

## 4. Electronic signatures

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **Sign Data / Signed Snapshots** | *"designed to help your organization comply with the FDA Code of Federal Regulations (CFR) Title 21 Part 11"* — links a data snapshot to a reason, a signatory, a date/time and *"unique and unrepeatable id number"*; signatories must re-authenticate. | *"Premium Feature — Available in the Enterprise Edition of LabKey Server."* | <https://www.labkey.org/Documentation/wiki-page.view?name=eSignatures> | **Yes** — and note what LabKey signs: a **snapshot** with an id. OSM §7 binds a **content hash** to the signer (FR-038), which is a stronger claim: LabKey's id is unrepeatable, but it is not derived from the content. |
| **ELN review, sign and approve** | Submit → review → approve/reject; **each signing event records the re-authentication configuration used** (e.g. *"SAML / Okta"*, *"CAS / labkey.org"*). | *"Available in: SM Professional…"* | <https://www.labkey.org/limshelp/wiki-page.view?name=elnReview> | **Yes** — PR-025, PR-026. The recorded re-auth *configuration* is a detail OSM should copy: a signature made under a weakened auth path must be distinguishable later. |
| **Notebook amendment** | Amend an already-approved notebook rather than creating a new one. | *"Available in: SM Professional…"* | <https://www.labkey.org/limshelp/wiki-page.view?name=elnAmend> | **Yes** — CON-004, PR-026. |
| **Customise the ELN ID naming pattern** | Site-wide notebook ID pattern. | *"Available in: LIMS Enterprise, Biologics LIMS"* | <https://www.labkey.org/limshelp/wiki-page.view?name=elnID> | Low priority — PR-010's engine covers it. |

## 5. PHI handling and column-level security

The most important row in this document, because it is the one most likely to
produce a wrong belief.

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **Use PHI levels to control UI visibility** | *"Subscribers to the Enterprise Edition of LabKey Server can use PHI levels to control display of columns in the user interface."* Community Edition can **set** PHI levels, which then filter export and study publishing — it cannot use them to hide anything at read time. | star + *"Premium Features Available … Enterprise Edition"* | <https://www.labkey.org/Documentation/wiki-page.view?name=phiLevels> | **No — OSM sidesteps it.** PRO-001 forbids PHI in OSM and PRO-003 strips it before publish, at row-build time (ADR-0005). This page is the documentation-side confirmation of the source-side finding in `labkey-ce-ground-truth.md`: **a PHI tag in CE masks nothing.** Anyone who tags a column PHI in CE and believes it is protected is wrong, and LabKey's own page says as much if read carefully. |
| **Row and column-level security via PHI** | Same premium callout on the dataset row/column security topic. | star + Enterprise | <https://www.labkey.org/Documentation/wiki-page.view?name=securityRowLevel> | **Yes** — FR-012, PR-029. And note: this is *not* PostgreSQL row-level security. It is dataset-level permission plus PHI column filtering. Neither product has database-enforced RLS. |
| **Biologics: protect sequence fields** | Protein and nucleotide sequences hidden from users lacking access, *"implemented using the mechanism LabKey uses to protect PHI… marked as 'Restricted PHI' by default."* | *"Available in: Biologics LIMS"* | <https://www.labkey.org/limshelp/wiki-page.view?name=biologicsPHI> | No — out of scope. |

## 6. Folder archives (export, import, reload)

Manual folder export and import, permission-settings export/import, study
export/import and list archives are **unbadged, i.e. Community**. That matters:
PRO-004 forbids `addWebPart` and requires portals to be delivered as folder
archives, and the mechanism is free.

Four things inside the archive are not:

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **ETL definitions in a folder archive** | Export/import extract-transform-load definitions as part of the archive. | inline *(Premium feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=importExportFolder> | No — OSM has no ETL definitions to publish. |
| **Inventory locations and items in a folder archive** | *"If any freezers have been defined in Sample Manager in this container, you will see this checkbox to include freezer definitions and storage information in the export."* | inline *(Premium feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=importExportFolder> | **Consequence, not a gap.** A CE folder archive **cannot carry storage**. The bridge cannot round-trip freezer layout through LabKey, so OSM's storage model has no downstream representation at all — it is OSM-only by construction. Worth stating explicitly in the FRD for PR-031. |
| **File Watcher: reload folder archive** | Automates reloading a folder from an unzipped archive. | *"Available with all Premium Editions."* | <https://www.labkey.org/Documentation/wiki-page.view?name=fileWatchTasks> | No — the outbox worker (ADR-0005) is OSM's own delivery mechanism and does not depend on file watchers. |
| **Automated study/dataset reload** | *"Subscribers to premium editions… can enable automated reload either of individual datasets from files or of the entire study from a folder archive."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=studyReload> | No. |

Also relevant, from the release-notes survey rather than the doc tree:
**sample status types and values are exported and imported with folder archives
only when the `sampleManagement` module is present** (server 22.3), and that
module is premium. A CE archive round-trip loses status definitions.

## 7. Storage and freezer management

**The entire subsystem is a different product.** Every page below is badged
*"Available in: SM Starter, SM Professional, LIMS Starter, LIMS Enterprise,
Biologics LIMS"* — five paid tiers and no free one.

| Feature | What it does | URL |
| --- | --- | --- |
| Freezer / storage overview | Digital storage systems mirroring physical freezers, incubators and room-temperature storage. | <https://www.labkey.org/limshelp/wiki-page.view?name=smFreezer> |
| Create a freezer | *"Create as many digital storage systems in the application as you have physical storage locations."* | <https://www.labkey.org/limshelp/wiki-page.view?name=createFreezer> |
| Store samples in a freezer | Assign samples to the virtual location matching the physical one. | <https://www.labkey.org/limshelp/wiki-page.view?name=storeFreezer> |
| Freezer details, manage freezer, manage stored samples | Overview and storage tabs, Manage menu, sample actions direct from the storage view. | `=freezerDetails`, `=manageFreezer`, `=manageStored` |
| Physical location grouping | Organise multiple storage systems by room, floor, building. | <https://www.labkey.org/limshelp/wiki-page.view?name=freezerLocation> |
| Move samples between locations | Move within or between storage units, boxes and plates. | <https://www.labkey.org/limshelp/wiki-page.view?name=freezerMove> |
| Storage migration / bulk import | Bulk import and update to migrate storage data from another system. | <https://www.labkey.org/limshelp/wiki-page.view?name=freezerMigrate> |
| **Check-out and check-in** | Check a sample out of storage and back in, recording volume consumed and freeze/thaw count. | <https://www.labkey.org/limshelp/wiki-page.view?name=checkout> |
| Manage storage units | Customise terminal and non-terminal units — boxes, plates, racks, shelves. | <https://www.labkey.org/limshelp/wiki-page.view?name=manageUnits> |
| Storage Editor / Storage Designer roles | Two roles specific to managing physical sample storage. | <https://www.labkey.org/limshelp/wiki-page.view?name=freezerRoles> |

**OSM must build all of it on CE**: FR-003, FR-016, FR-028 through FR-032,
FR-058, NFR-001, plus the new FR-073, FR-074 and NFR-008. This is PR-016
through PR-020 and PR-048, PR-049 — the largest single block of work in the
backlog, and `gap-analysis.md` already scores it `high`.

One storage-adjacent item sits on the LabKey Server side instead:

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **Barcode / UniqueID fields** | LabKey-generated identifiers unique across the deployment, encodable as barcodes. | *"Premium Feature — Available with all Premium Editions of LabKey Server."* | <https://www.labkey.org/Documentation/wiki-page.view?name=uniqueStorageIds> | **Yes — but note the trap.** `labkey-ce-ground-truth.md` proves the block is **client-side only**: `property-createDomain.api` with `conceptURI: http://www.labkey.org/types#storageUniqueId` creates a working barcode field in CE. The documentation says premium; the server does not enforce it. Do not conclude the bridge cannot create barcode fields downstream — it can. |

## 8. Workflow

All badged *"Available in: SM Professional, LIMS Starter, LIMS Enterprise,
Biologics LIMS"* — **excluded from SM Starter as well as from Community**.
Workflow is one tier above the freezer.

| Feature | What it does | URL |
| --- | --- | --- |
| Lab Workflow | Jobs tracking and prioritising sequential tasks, assignment, templates, progress. Requires admin or the **Workflow Editor** role. | <https://www.labkey.org/limshelp/wiki-page.view?name=workflow> |
| Start a new job | Jobs organise related tasks; samples and sources attached; direct data-upload links. | <https://www.labkey.org/limshelp/wiki-page.view?name=startJob> |
| Manage job queue | Your queue on the home page, plus jobs assigned to others. | <https://www.labkey.org/limshelp/wiki-page.view?name=manageQueue> |
| Complete tasks | Mark tasks and jobs complete. | <https://www.labkey.org/limshelp/wiki-page.view?name=completeTasks> |
| Edit jobs and tasks | Update details, rename, add and delete files. | <https://www.labkey.org/limshelp/wiki-page.view?name=editJob> |
| Job templates | Standardise common task sequences. **Only administrators can create job templates.** | <https://www.labkey.org/limshelp/wiki-page.view?name=jobTemplate> |
| **Job template actions** | Guided actions and buttons on each task, for standardisation and automation. | *second badge, "Available in: LIMS Starter…"* — same page |
| Manage jobs and templates | Admin management of the job and template lists. | <https://www.labkey.org/limshelp/wiki-page.view?name=manageJobs> |
| Assay Request Tracker (Server side) | Issue-tracker extension for requesting assays on samples. | *"Premium Feature — Available **upon request** with all Premium Editions."* — <https://www.labkey.org/Documentation/wiki-page.view?name=assayRequest> |

**OSM must build all of it on CE**: FR-004, FR-017, FR-033 through FR-036,
FR-059, plus the new FR-075. PR-021 through PR-023 and PR-050.

Note the tiering, which is the single most useful thing this sweep established
about workflow: **job templates are SM Professional; template *actions* — the
guided buttons that make a template do something rather than merely list steps
— are LIMS Starter.** OSM's FR-033 and the new FR-075 together sit at LabKey's
LIMS Starter tier, not at Sample Manager's.

## 9. Sample management

The split matters and is easy to get wrong. **LabKey Server Community *does*
have Sample Types, naming patterns, aliquot naming patterns, lineage and
derivation, and lineage graphs** — those `/Documentation` pages carry no badge,
and `gap-analysis.md` already scores them `native`. What is premium is the
**Sample Manager application** and everything expressed only inside it.

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| Sample Manager application: sample types, samples, sources | Sample Types as the framework; add and import samples; Sources, physical and biological, mapped to samples. | SM Starter+ | `=samples`, `=createSampleType`, `=importSampleSets`, `=sources`, `=createSources` | **Yes** — FR-014, FR-023, PR-009, PR-011. |
| **Aliquots** | Split a sample into aliquots retaining parent properties; separate aliquot naming patterns and statuses. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=aliquots>, `=aliquotIDs` | **Yes** — FR-015, FR-025, PR-013, plus new FR-068. |
| **Sample status** | Available / Consumed / Locked plus custom values, colour-coded; aliquots carry their own status. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=sampleStatus> | **Yes** — FR-022, PR-012. And CE's version enforces nothing (`labkey-ce-ground-truth.md`). |
| **Picklists** | User-defined and shared lists for bulk sample operations. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=samplePicklist> | **Yes** — FR-027, PR-028. |
| **Sample Finder** | Find samples across all types by sample, parent and source properties — *"or in the Professional Edition, based on related assay results."* | SM Starter+; assay-result criteria SM Professional+ | <https://www.labkey.org/limshelp/wiki-page.view?name=sampleFinder> | **Yes** — FR-006, FR-039, PR-027. The assay-threshold facet OSM specifies is at LabKey's *higher* tier. |
| Sample and barcode search | Search by Sample ID or barcode, over UniqueID fields and barcode-designated fields. | SM Starter+ | `=sampleSearch`, `=search` | **Yes** — PR-019, PR-027. |
| **Sample expiration and built-in reports** | Expiration Date system field; reports for soon-expiring stock and low aliquot counts. | SM Starter+ | `=sampleExpiration`, `=sampleReports` | **Yes — new.** FR-069, PR-043. |
| Barcodes (UniqueID) in the app | LabKey-generated barcodes unique across the application. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=uniqueStorageIds> | **Yes** — FR-050 territory, PR-019. |
| **BarTender label printing (use)** | Send sample labels to the BarTender web service. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=barTender> | **No — flagged.** LabKey's only label path is a commercial Windows product. §15 asks for ZPL. `labkey-release-notes-survey.md` §7 recommends not adopting BarTender. |
| BarTender setup (admin) | One-time configuration of the integration, print portal and certificates. | SM Professional+ | <https://www.labkey.org/limshelp/wiki-page.view?name=setupBarTender> | No. |
| **Folders / data partitioning** | *"Folders allow users to organize and partition sensitive data within the application."* | SM Professional+ | <https://www.labkey.org/limshelp/wiki-page.view?name=folders> | **Yes** — FR-014's Project entity and PR-029's RLS. Note LabKey charges a tier for data partitioning; OSM puts it in the database. |
| **Cross-folder actions** | Move samples, sources, assay runs, workflow jobs and notebooks between folders. | SM Professional+ | `=crossFolder`, `=viewSampleSets`, `=viewSourceTypes` | **Flagged.** Not in the OSM specification. Moving an audited object between security scopes is a genuine design question, not a convenience. Recommend an ADR before anyone implements it. |
| Sample Manager inside a LabKey Server project | *"Premium Editions of LabKey Server include the option to use the Sample Manager application within a project and integrate with LabKey Studies…"* | SM Professional+ | <https://www.labkey.org/limshelp/wiki-page.view?name=smProject> | N/A — ADR-0001 makes OSM standalone. |
| Link samples to LabKey Studies | Connect sample data to study demographic and clinical data. | SM Professional+ | <https://www.labkey.org/limshelp/wiki-page.view?name=smStudies> | **Partly** — FR-061's `P-LK-STUDY` and CON-009. The CE-side study linking is not premium; the in-app version is. |
| Custom import templates | Admin-provided import templates per data structure. | LIMS Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=downloadTemplate> | Low priority — PR-014. |
| Assay designs, import and management in the app | Assay work inside SM/LIMS. | SM Professional+ | `=assays`, `=importAssay`, `=manageAssayData`, `=manageAssayDesign` | **Partly** — FR-019, FR-061. CE has Standard Assay natively. |
| Grid charts in the app | Server-defined charts above LIMS data grids. | LIMS Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=bioCharts> | Low priority. |
| **Run Builder (provenance)** | Streamlines creating experiment runs with inputs and outputs. LabKey: the `provenance` module *"is available with Premium Editions… but is not currently included in all distributions."* | Premium **and** conditional | `=deriveSamples`, `=runBuilder` | No — OSM's lineage model (PR-013) is its own. |

### Biologics LIMS only — the top tier

All badged *"Available in: Biologics LIMS"*. **`labkey-release-notes-survey.md`
§7 recommends every one of these as out of scope for OSM**, and they are listed
here so the exclusion is visible.

| Feature | What it does | URL |
| --- | --- | --- |
| Media, mixtures, ingredients, recipes | *"Mixtures are recipes that combine Ingredients using specific preparation steps"*; registration wizard, bulk ingredients, Recipe API. | `=media`, `=mediaReg` |
| Bioregistry / molecule registration | Register molecules and molecular species by GUI, bulk or API. | `=moleculeRegistry`, `=editBioregistry`, `=registration` |
| Plates and plate sets | Antibody screening and characterisation; plate well metadata linked to samples, registry sources and sequences. | `=plates` |
| Reclassify sequences and molecules | Update annotations affecting physical property calculations. | `=reclassify` |
| Biologics registration API / identity service | Register entities outside the app. | `=api` |
| ELN tags | Colour-coded tags to organise and prioritise notebooks. | `=elnTags` |

## 10. Electronic lab notebook

All badged *"Available in: SM Professional, LIMS Starter, LIMS Enterprise,
Biologics LIMS"* — not SM Starter, and not LabKey Server Community.
Corroborated on the Server side: *"You can use a data-integrated Electronic Lab
Notebook (ELN) within LabKey LIMS, Biologics LIMS, and the Professional Edition
of Sample Manager."*
(<https://www.labkey.org/Documentation/wiki-page.view?name=labWorkflow>)

| Feature | URL |
| --- | --- |
| ELN overview — notebooks integrated with samples and assay data | <https://www.labkey.org/limshelp/wiki-page.view?name=sampleELN> |
| Create notebooks; notebooks dashboard | `=elnCreate`, `=elnDash` |
| Notebook templates | `=elnTemplates` |
| References — link notebooks to samples, sources, assay data, jobs | `=elnReference` |
| Review, sign and approve workflow | `=elnReview` |
| Amend an approved notebook | `=elnAmend` |
| Export as PDF / signed archive (**requires a Puppeteer service**) | `=elnExport`, `=puppeteer` |
| Customise the notebook ID naming pattern | `=elnID` — *LIMS Enterprise, Biologics LIMS* |

**OSM must build all of it on CE**: FR-005, FR-018, FR-037, FR-038, FR-060,
CON-004, plus the new FR-077 and FR-078. PR-024 through PR-026, PR-051,
PR-052. `gap-analysis.md` scores it `high` and the `labbook` module is absent
from CE entirely.

One operational note worth carrying into PR-026: LabKey's ELN **PDF export
requires a separate Puppeteer (headless Chrome) service**. Rendering a signed,
legally meaningful PDF is not a library call, and OSM's PDF requirement inherits
that cost.

## 11. Notifications

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **Email notification for workflow jobs** | *"For Sample Manager (Premium Feature): workflow job notifications… You will only see this option on servers where the Sample Manager application is available."* | inline *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=folderNotifications> | **Yes** — FR-035, PR-023. |
| **Email notification for the ELN** | *"For ELN (Premium Feature): notebook authoring and review notifications."* | inline *(Premium Feature)* | same page | **Yes** — PR-025. |
| In-app notifications | Bell-menu notifications, background-import progress. | SM Starter+ | <https://www.labkey.org/limshelp/wiki-page.view?name=notifications> | **Yes** — PR-023. |
| Per-user email preferences for Notebooks and Workflow | *"Users of the Professional Edition of Sample Manager can control whether they receive email for either Notebooks or Workflow or both."* | SM Professional+ | same page | **Yes** — PR-023. Users switching off due-date escalation raises a question FR-035 does not answer: is escalation opt-out-able? |
| Project Review Email Recipient role | Project admins with this role get emails about projects needing review. | star + *(Premium Feature)* | <https://www.labkey.org/Documentation/wiki-page.view?name=permissionLevels> | No — access recertification, flagged. |
| Panorama outlier notifications | Per-user subscription to QC outlier notifications. | *"Panorama Premium Edition… or PanoramaWeb"* | <https://www.labkey.org/Documentation/wiki-page.view?name=premPanoNotifications> | No — out of scope. |

## 12. Security, roles and authentication

| Feature | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- |
| **Multiple authentication configurations and methods** — *"The ability to add other authentication methods and to define multiple configurations of each method is available with all Premium Editions."* | all Premium | <https://www.labkey.org/Documentation/wiki-page.view?name=authenticationModule> | **Yes** — FR-013. **CE has database logins and nothing else.** OSM's OIDC requirement (PR-006) cannot lean on LabKey at all. |
| LDAP authentication | all Premium | `=configLdap` | Not specified — OIDC only. |
| LDAP user/group synchronisation | all Premium | `=LDAP_sync` | Not specified. |
| SAML authentication | all Premium | `=saml` | Not specified. |
| CAS authentication (client) | all Premium | `=configureCas` | Not specified. |
| CAS identity provider (server) | all Premium | `=configureCasIp` | No. |
| Duo two-factor authentication | all Premium | `=configureDuoTwoFactor` | **Flagged** — no MFA requirement exists. For a system that signs records (FR-038), that is a gap worth raising. |
| TOTP two-factor authentication | all Premium | `=configureTotpTwoFactor` | Same. |
| Require Secondary Authentication role | star + *(Premium Feature)* | `=permissionLevels` | Same. |
| **Trusted Analyst role** — write code that runs sandboxed on the server *and* share it for others to run under their own user ids | all Premium | `=devRoles` | **No — and note the hazard.** Code running under another user's identity is exactly the privilege-escalation shape CON-012 and PRO-009 exist to prevent. |
| Analyst role — write code that runs on the server, without sharing | all Premium | `=devRoles` | No. |
| Module Editor role; module editing via the server UI | star; *"Professional and Enterprise… requires the `moduleEditor` module"* | `=permissionLevels`, `=moduleEditing` | No. |
| QC Analyst role | star + *(Premium Feature)* | `=permissionLevels` | No. |
| PHI reader roles (Restricted / Full / Limited) | star + *(Premium Feature)* | `=permissionLevels` | No — PRO-001. |
| Launch and use RStudio Server role | star + *(Premium Feature)* | `=permissionLevels` | No. |
| **Virus checking (ClamAV)** — scan uploads, attachments, pipeline and WebDAV content | *"Available with all Premium Editions."* | `=virusChecking` | **Flagged.** OSM accepts CSV uploads and ELN attachments (PR-014, PR-024). AGENTS.md §3 bounds size, validates content type and neutralises formula injection, but says nothing about malware. Recommend raising it. |
| Permissions Review Enforcement | star + Enterprise | `=configuringPerms` | Flagged — access recertification. |
| Best Practices: Security Scans | *"(Available only to Premium Edition subscribers)"* on the Security hub | `=premScanningGuidelines` | No. |

## 13. ETL, integration and external data sources

Comprehensively premium; none of it is in OSM's scope, and it is catalogued so
that nobody plans a LabKey-side integration path that turns out to cost money.

| Feature | Edition | URL |
| --- | --- | --- |
| **ETL module in full** — definitions, XML editor, transform types and tasks, schedules, queuing, stored procedures, logging and error handling, module structure | *"Available with all Premium Editions."* | `=etlModule`, `=etlUI`, `=etlXMLEditor`, `=etlTasks`, `=etlSchedule`, `=etlCallOtherETL`, `=etlsproc`, `=etlError`, `=etlReference` |
| ETL remote connections | all Premium | `=remoteConnection` |
| **File Watchers** | all Premium | `=fileWatcher`, `=fileWatchTasks` |
| External Oracle data sources | all Premium | `=externalOracle` |
| External SAS/SHARE data sources | all Premium | `=externalSAS` |
| External Amazon Redshift data sources | Professional and Enterprise | `=redshift` |
| External Snowflake data sources | Professional and Enterprise | `=snowflake` |
| Non-PostgreSQL external schemas generally | Premium | `=externalSchemas` |
| REDCap survey data integration | Professional and Enterprise; **add-on to Starter** | `=redCap` |
| Medidata Rave integration | Professional and Enterprise | `=medidata` |
| CDISC ODM XML integration | all Premium | `=cdiscImport` |
| **S3 cloud storage** (config, files, watchers) | Professional and Enterprise; add-on to Starter | `=cloudStorage`, `=cloudConfig`, `=cloudFiles`, `=cloudWatch` |
| AWS Glue integration | as cloud | `=glue` |
| **ODBC / JDBC external analytics connections** | Professional and Enterprise | `=secureODBC`, `=odbcWindows`, `=configConnectors`, `=LabKeyJDBCDriver` |
| Tableau integration | Professional and Enterprise | `=tableau` |
| Spotfire integration | Professional and Enterprise; add-on to Starter | `=spotfire` |
| DBVisualizer integration | as Spotfire | `=dbVisualizer` |
| SSRS reporting | Professional and Enterprise | `=ssrs` |
| RStudio / RStudio Workbench integration | Professional and Enterprise | `=rstudio`, `=docker`, `=RSpro` |
| **Ontology integration** — controlled vocabularies, concepts, hierarchies, synonyms | *"Available in the Enterprise Edition."* | `=ontology` |
| **LIMS Enterprise "SDMS features" bundle** — custom wikis and dashboards, Collaboration folders, Lists, Files, R Reports, custom SQL, File Watchers, ETLs, external DB connections, ODBC/JDBC, SSO | *"Features Available In: LIMS Enterprise, Biologics LIMS"* | <https://www.labkey.org/limshelp/wiki-page.view?name=limsEnterprise> |

**Consequence for OSM.** §16 maps OSM objects onto CE modules that are all free
— `experiment`, `assay`, `list`, `pipeline`, `wiki`, `visualization`, `audit`.
Nothing in the publish path (PR-030 through PR-032) touches a premium
integration. That is worth stating: **the bridge is designed against the free
surface and stays there.**

## 14. API and MCP

| Feature | What it does | Edition | URL | OSM must build on CE? |
| --- | --- | --- | --- | --- |
| **LabKey MCP Server** | *"provides a standardized way for AI agents and external tools to securely interact with LabKey Server… making it possible for intelligent clients to discover datasets, run SQL queries, and perform analysis."* | *"Premium Feature — Available in the Professional and Enterprise Editions of **LabKey SDMS**."* (the only page using "SDMS" in a badge) | <https://www.labkey.org/Documentation/wiki-page.view?name=mcp> | **Yes** — FR-008, FR-044, PR-033, PR-034. And note the design difference: LabKey's MCP *"run SQL queries"* is precisely what PRO-009 forbids OSM from exposing. |
| **API keys** | Revocable, expiring token credentials for scripts and AI agents. Role-restrictable since 26.7. | **No premium marker — Community** | <https://www.labkey.org/Documentation/wiki-page.view?name=apiKey> | No — CE provides it, and ADR-0008 and `AGENTS.md` §3 already build on it. |
| **Session keys** | Compliant programmatic access tied to a login session. | **No premium marker — Community** | <https://www.labkey.org/Documentation/wiki-page.view?name=apiSessionKey> | No. |
| SM/LIMS API access | labkey.com's Sample Manager pricing table lists *"API Access & Support"* as SM Professional only, not SM Starter. | labkey.com table, **not a doc badge** | <https://www.labkey.com/products-services/sample-management-software/> | N/A — a pricing claim with no documentation counterpart. |

## 15. Search

Core full-text (Lucene) search and Search Administration are **unbadged, i.e.
Community**: <https://www.labkey.org/Documentation/wiki-page.view?name=luceneSearch>,
`=searchAdmin`. Three caveats, all recorded verbatim:

- `searchAdmin`: *"There are a number of startup properties related to the
  search index… **Users of Premium Editions** can learn more about them on the
  Admin Console."*
- `luceneSearch`: *"If you are looking for details about search in LabKey Sample
  Manager and LIMS products, see these topics… **Not all features described in
  this topic are available in those products**."*
- SM/LIMS in-app search and sample/barcode search are premium
  (`limshelp/search`, `limshelp/sampleSearch`).

`gap-analysis.md` already records the decisive point, which no documentation
page states: **CE's search has no faceting at all.** Free text is free;
FR-039's faceted finder is OSM's own work (PR-027).

Also: *"Search LabKey Documentation with an AI Agent"* is a section of the
premium MCP page, not a separate feature
(<https://www.labkey.org/Documentation/wiki-page.view?name=mcp>).

## 16. Other premium items catalogued

| Feature | Edition | URL |
| --- | --- | --- |
| QC Trend Reports | all Premium | `=qcTrend`, `=qcTrendReport` |
| Assay QC States (admin) | all Premium | `=assayQCconfig` |
| Panorama Premium (QC folders, outlier notifications) | Panorama Premium / PanoramaWeb | `=panoQCfolder`, `=premPanoNotifications` |
| PremiumStats CLR aggregates for MS SQL Server — median, MAD, quartiles, IQR | inline, Premium | `=premiumaggregateinstall` |
| ETL stored procedures on MS SQL Server — *"(Existing Premium Edition Users Only)"* | inline | `=etlsproc` |
| **Adjudication module** — *"legacy feature that requires significant customization… **It is not included in standard LabKey distributions.**"* | contact LabKey | `=adjudication` |
| **ActiveMQ JMS queue pipeline** — *"not a typical configuration and may require significant customization."* | contact LabKey | `=jmsQueue` |
| Premium Documentation ("Advanced Topics") hub | labkey.com lists it Starter/Pro/Enterprise; the page itself is unbadged | `=premiumResources` |

None is in OSM's scope.

---

## 17. Where LabKey's own sources disagree

Recorded, not resolved. Each is a place where believing one source would mislead.

1. **The ELN is scoped on two different axes.** labkey.com's SDMS matrix marks
   the ELN Professional + Enterprise **of LabKey Server**. The doc badges scope
   it to **SM Professional, LIMS Starter, LIMS Enterprise, Biologics LIMS** —
   *product* editions. The two axes are not reconciled anywhere.
2. **Enterprise LabKey Server gets the *Professional* tier of Sample Manager.**
   labkey.com's row reads Community "–", Starter "Starter Edition", Professional
   "Professional Edition", Enterprise "**Professional Edition**". No
   documentation page states this mapping.
3. **21 CFR Part 11 is claimed in two places with different scopes.**
   labkey.com's SDMS matrix puts it in Enterprise LabKey Server; the docs agree
   for the Compliance module. But `limshelp/enterpriseGov` puts Part 11
   electronic signatures in **LIMS Enterprise / Biologics LIMS**, a product line
   the SDMS matrix does not cover at all.
4. **S3, REDCap, CDISC and Spotfire**: the docs are *more permissive* than the
   pricing matrix — they add *"Also available as an Add-on to the Starter
   Edition"*, which the matrix does not show.
5. **The MCP Server appears nowhere on labkey.com's matrix**, and its doc badge
   is the only one in the corpus that says *"LabKey SDMS"* rather than *"LabKey
   Server"*.
6. **Sample Manager has no free tier.** The pricing table shows only Starter and
   Professional columns, both paid — consistent with the total absence of a
   "Community" chip in the `limshelp` badge vocabulary. It also lists **HIPAA
   Compliance** and **Software Validation** as paid *add-ons* to SM Professional,
   which no labkey.org page mentions.
7. **Dataset QC states may or may not be Community.** `manageQC` is unbadged
   while its sibling `assayQCconfig` is explicitly premium, and labkey.com lists
   "Quality Control and Trend Reporting" as non-Community.
8. **The same capability is documented twice under two vocabularies.**
   `limshelp/uniqueStorageIds` (SM Starter+) and
   `Documentation/uniqueStorageIds` (*"all Premium Editions of LabKey Server"*)
   describe the same barcode field. Which is also the capability
   `labkey-ce-ground-truth.md` proves works in CE anyway.

### Pages where the premium marking could not be resolved

- **`prem*`-prefixed pages with no badge**: `premSecurityRole`, `premJSsecurity`,
  `premTransformScript`, `premCSPdev`, `premSplitUpload`, `premDataFinder`,
  `premChangeKey`, `premScanningGuidelines`, `etlBestPractices`. All sit under
  the "Advanced Topics" hub and are named `prem…`, but carry no badge and no
  star. Only two are marked indirectly, from their parent pages. **Unresolvable
  from the doc pages alone.**
- **`gdpr`** — no badge at all, yet everything it prescribes lives in the
  Enterprise-only Compliance module. Reads as Community-available guidance for a
  premium-only capability.
- **`runBuilder`** — premium *and* conditional: *"not currently included in all
  distributions."*
- **`assayRequest`** — premium *and* gated: *"Available upon request."*
- **`limitUsers`, `premChangeKey`, `securityAPI`, `exportperms`,
  `serverSideValidation`, `datasetNotification`, `sasAPI`** — unbadged, treated
  here as Community.
- **`biologics`** (`/Documentation`) returns *"This Wiki web part is not
  configured to display content."* — a broken page, not a 404.

## 18. Pages that do not exist

Seventeen names returned HTTP 200 with a body of *"This page has no content."* —
LabKey's soft-404. Recorded so nobody re-derives them, with the correct name
where one was found:

| Probed | Correct page |
| --- | --- |
| `folderArchive`, `exportFolder`, `importFolder` | `importExportFolder` |
| `backupAndRestore` | `dbBackup` / `backupRestore` |
| `etl` | `etlModule` |
| `ssoConfig` | `authenticationModule` / `saml` / `configureCas` |
| `sampleManager` | the whole `/limshelp` container |
| `antiVirus`, `virusCheck` | `virusChecking` |
| `encryptionKey` | `premChangeKey` |
| `limitActiveUsers` | `limitUsers` |
| `labkeyDataFinder` | `premDataFinder` |
| `inventoryStorage`, `storage` | `limshelp/smFreezer` |
| `dataspace` | none found |
| `/limshelp`: `bioProject`, `bioregistry` | `editBioregistry` / `moleculeRegistry` |

`phi` is a **301 redirect** to `phiLevels`, not a 404.
`https://www.labkey.com/products-services/labkey-server/sdms-pricing/` is a real
404.

## 19. Summary: what this changes for OSM

Nothing in the plan. That is the useful result — **a 265-page sweep of LabKey's
documentation did not overturn a single conclusion in `docs/gap-analysis.md`.**
It sharpened three of them:

1. **The boundary is a product boundary, not a feature boundary.** Storage,
   workflow, ELN, picklists and the finder are not premium features of LabKey
   Server; they are a separate paid product whose cheapest tier is not free.
   ADR-0001's "there is no CE substrate to extend" is confirmed from LabKey's
   own documentation.
2. **The tiering inside that product is not where you would guess.** Freezer
   management, check-in/check-out, aliquots, picklists, barcodes, status and the
   Sample Finder are the *cheapest* tier. Workflow, the ELN, folders and
   cross-folder moves are one tier up. Template *actions* and Part 11 signatures
   are two and three tiers up. OSM's specification spans all four.
3. **Backup and restore is nobody's premium feature, and LabKey documents no
   PITR and no restore drill at any price.** NFR-006 and PR-038 are stricter
   than the commercial product. There is prior art in PostgreSQL and none in
   LabKey.

Two things this sweep added that were not in the plan and now are: FR-070
(reason for change) and FR-069 (sample expiry), both derived here and in the
release-notes survey. Four things it flagged and left open: read-access
auditing, multi-factor authentication for signatories, malware scanning of
uploads, and cross-folder moves of audited objects.

## Sources

265 labkey.org wiki pages and 2 labkey.com pages, each cited inline above.
Entry points:
<https://www.labkey.org/Documentation/wiki-page.view?name=default>,
<https://www.labkey.org/Documentation/wiki-page.view?name=prevreleases>,
<https://www.labkey.org/limshelp/wiki-page.view?name=limsSuiteReleaseNotes>,
<https://www.labkey.com/products-services/labkey-server/#editions>,
<https://www.labkey.com/products-services/sample-management-software/>.

Nothing on this page has been verified against `/root/scicore` or the running
server. Where it touches a claim that has been, the ground-truth page is cited
and **the ground truth wins**.
