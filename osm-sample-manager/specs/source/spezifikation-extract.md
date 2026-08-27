<!--
Verbatim structural extraction of the source specification.

Source file : OSM_Sample_Manager_Spezifikation.docx
Title       : Spezifikation: Open Sample Manager
Origin      : Universitaet Basel - Biomed / Open LIMS
Version     : 1.1, 21 August 2026
Extracted   : 2026-08-26 from word/document.xml (paragraphs + tables, in order)

This file is evidence, not a work product. Do not edit it to "improve" the
wording - it must keep matching the .docx. Requirements derived from it live in
the memory database (tools/memory.py list requirements) with a `source` field
pointing back at the section numbers used below.
-->

Universität Basel · Biomed / Open LIMS
Spezifikation: Open Sample Manager
Open-Source-Eigenlösung für Probenlebenszyklus, Freezer-Map, Job-Queue, ELN, Suche, Audit, LabKey-Publish und MCP-API. Unabhängig von LabKey-Produkten.
Version 1.1 · 21. August 2026 · LabKey-Importmodule, Workflow-Pipelines, LLM/MCP

# Inhaltsverzeichnis

# 1. Ziel und Abgrenzung
OSM registriert, lagert, bearbeitet, dokumentiert und sucht Proben, publiziert nach LabKey CE und bindet Assistenten über REST/MCP an.
Chain of Custody.
Freezer-Map 1:1.
SOP-Jobs mit Queue.
ELN mit Signatur.
Facettierte Suche.
Hash-Audit.
REST plus MCP.
LabKey-Publish ohne addWebPart.
Apache-2.0 / CC-BY-4.0.
Kein LabKey-UI-Klon.
Kein SPHN-/USB-Patientenpayload.
LabKey ist Downstream.

# 2. Architektur
UI, API-Gateway, Domain-Dienste, PostgreSQL mit RLS, Object-Store. Jede Schreiboperation auditiert in derselben Transaktion.

[TABLE]
Komponente | Verantwortung
identity-service | OIDC, Rollen, API-Keys
registry-service | Typen, Samples, Lineage
storage-service | Lagerhierarchie
workflow-service | Jobs, Queue
eln-service | Notebooks, Signatur
search-service | Finder
audit-service | Hash-Kette
file-service | Dateien, Labels
labkey-bridge | Outbox  Importmodule
mcp-server | Tools = REST-Semantik
notify-service | Mail/Webhook
[/TABLE]


# 3. Domänenmodell

[TABLE]
Entität | Schlüssel | Felder
Project | project_id | name, retention
SampleType | sample_type_id | pattern, fields, statuses
Source | source_id | human_id, meta
Sample | sample_id | status, barcode, slot
AliquotLink | parent+child | aliquot|derived
StorageNode/Slot | ids | geometry, occupied_by
Job/Task | ids | owner, due, status
Notebook | notebook_id | status, hash
AssayRun | run_id | design, samples
AuditEvent | event_id | before, after, prev_hash
PublishOutbox | outbox_id | target, state
[/TABLE]

Status: Registered  Available  Reserved  In Process  Consumed | Locked | Discarded | Shipped.

# 4. Registry
Typ-Designer, CSV, Aliquot/Derivat, Timeline, Picklists. Study-PID nur als Token.

# 5. Freezer-Map

[TABLE]
Ebene | Geometrie | Regel
site/building/room | Liste | Struktur
device | Status | Zone
rack/drawer | Raster | Kapazität
box/plate | rows×cols | A1
slot | Zelle | eine Probe
[/TABLE]

Check-in/out/Move atomar.
Box-Move als Batch.
TTL-Reservierung.
Slot-Konflikt 409.
1000 Boxen à 81 Slots ohne Ruckeln.

# 6. Job-Queue
Templates ohne Proben. Queue: meine Tasks, Active Jobs, Board. Eskalation T-1/T+1. Optimistic Lock auf complete.

# 7. ELN
draft  review  approved  signed  locked. Signed unveränderlich. Signatur mit Re-Auth und JSON-Hash.

# 8. Suche
Facetten, Lineage, Lager, Assay-Schwellen. P95 < 300 ms bei 1e6 Proben. MCP a UI.

# 9. Auditierung
Append-only, SHA-256-Kette, Tages-Checkpoint, Trail-Export. Auditor nur lesen.

# 10. REST- und MCP-API

[TABLE]
REST / Tool | Zweck
POST /samples | Intake
POST /storage/moves | Lager
POST /jobs | Workflow
POST /notebooks/{id}/sign | ELN
GET /search | Finder
osm.samples.* | Registry via MCP
osm.storage.* | Lager via MCP
osm.jobs.* | Queue via MCP
osm.eln.append_ref | nur draft
osm.audit.for_entity | Trail
osm.labkey.publish_status | Bridge
[/TABLE]

confirm=true plus osm.admin.write für destruktive Aktionen. actor_type=mcp im Audit.

# 11. Berechtigungen

[TABLE]
Rolle | Darf
Reader | lesen
Technician | anlegen, lagern, eigene Tasks
Scientist | Jobs, ELN-Entwurf, Assays
Reviewer | signieren
Storage/Workflow admin | Struktur
Project admin | Typen, Mitglieder
Auditor | nur Trail
[/TABLE]


# 12. Oberfläche
Eigenes UX: Dashboard, Samples, Sources, Map, Workflow, ELN, Finder, Admin.

# 13. Iterationen

[TABLE]
It. | Lieferung | Done
I0 | Auth, Audit, OpenAPI | Hash-Kette
I1 | Registry | Aliquot
I2 | Freezer-Map | §5
I3 | Workflow | Queue
I4 | ELN | Signatur
I5 | Suche | RLS
I6 | MCP, LabKey-Bridge | UIaMCP
I7 | Betrieb | Runbook
[/TABLE]


# 14. Nichtfunktional
API P95 < 200 ms, 100 parallele Nutzer, 1e6 Proben, PITR 7 Tage, WCAG 2.2 AA anstreben.

# 15. Offene Punkte
Temperatur-Logger.
ZPL-Drucker.
DPIA vor USB-Identifikatoren.

# 16. LabKey-Importmodule
OSM ist System of Record. LabKey CE ist Publish-Ziel. APIs wie UCI/Biomed: CSRF, createContainer, Domain, query-import, wiki-save, WebDAV. Kein addWebPart. Portale als folder.xml-Zip.

## 16.1 Module

[TABLE]
LabKey-Modul | OSM-Objekt | Importweg
experiment / Sample Types | Sample, Aliquot, Lineage | Domain + query-import
experiment / Data Classes | Source | Domain + rows
assay (General, ELISA, NAb, Luminex) | AssayRun | Design/XAR, Run-Upload
targetedms | Skyline optional | Pipeline + .sky.zip
study | tokenisierte Kohorte | nur Subject+Timepoint
list | Kataloge, BAG | IntList + query-import
pipeline / filecontent | FASTQ/RAW-Zeiger | WebDAV @files
wiki | SOP, Quellenkarte | wiki-saveWiki.api
query / visualization | Charts | saveVisualization.api
audit (Server) | zusätzlicher Trail | nicht OSM ersetzen
[/TABLE]


## 16.2 Mapping und Bridge
Project  LabKey-Projekt/Unterordner.
human_id unique, plus AutoIncrement-Key.
Lineage als Lookups.
storage_path als String; Map bleibt in OSM.
Jobs als Listen-Read-Model.
ELN-PDF nach @files/eln/.
PHI beim Publish streichen.
osm_id für Idempotenz.
labkey-bridge (I6) arbeitet osm_publish_queue ab (sample.committed, assay.uploaded, notebook.signed). Fehler inkl. HTTP-Body in FAILED.

# 17. Workflow-Pipelines
Trigger  Validierung  Aktion  Audit  optional Notify/Publish/LLM.

## 17.1 Inventar und Lager

[TABLE]
Pipeline | Trigger | Schritte
P-INTAKE | create | Typ, ID, Source, Slot, Label
P-ALIQUOT | aliquot | Menge, Kinder, Lineage
P-DERIVE | neuer Typ | Typwechsel plus Parent
P-CHECKIN | move+Slot | belegen
P-CHECKOUT | move ohne Slot | frei, Reserved
P-BOXMOVE | Box | atomarer Batch
P-DISCARD | discard | Status, Slot frei
P-SHIP | Versand | Custody, Shipped
[/TABLE]


## 17.2 Arbeit und Dokumentation

[TABLE]
Pipeline | Trigger | Schritte
P-JOB-START | Template+Proben | Tasks, Queue, Notify
P-JOB-TASK | complete_task | Checkliste, nächster Schritt
P-JOB-BLOCK | blocked | Eskalation
P-ASSAY-UP | Datei | Parse, Match, Index
P-ELN-DRAFT | anlegen | Vorlage
P-ELN-REVIEW | submit | Reviewer-Queue
P-ELN-SIGN | Re-Auth | Hash, Lock, PDF
P-PICKLIST | Finder | Menge, Job-Start
[/TABLE]


## 17.3 LabKey und externe Daten

[TABLE]
Pipeline | Trigger | Schritte
P-LK-SAMPLE | Outbox sample | Sample Type, import
P-LK-ASSAY | assay.uploaded | Run + Wiki
P-LK-LIST | Katalog | folder.xml
P-LK-STUDY | Subject+Visit | sonst reject
P-GEO-META | Accession | Meta, kein FASTQ
P-UNIPROT | Accessions | Felder an Meta
P-BAG-SYNC | Cron Mi | IDD-CSV
P-SPHN-TOKEN | manuell | nur Konzeptkarte
[/TABLE]


## 17.4 Betrieb
P-REINDEX.
P-AUDIT-CKPT.
P-RETENTION.
P-KEY-ROTATE.
P-RESTORE-DRILL.

# 18. LLMs: Nutzen und Ansprache
LLMs nutzen nur MCP-Tools. Jeder Aufruf erzeugt llm.invoke (model_id, request_id). Keine Domain-Aktion ohne Tool.

## 18.1 Vorteilhaft

[TABLE]
Situation | Warum | Wirkung
Unsauberer CSV-Intake | Mapping | Vorschlag, create nach confirm
SOP  Template | Schritte | Entwurf für Editor
Finder in Sprache | Facets | search.query, DSL zeigen
Freie Plätze | Pfad | locate + find_empty
Queue priorisieren | Kontext | nur lesen
ELN kürzen | Text | draft-Block
Assay-Mismatch | Erklärung | Korrekturvorschlag
Audit-Frage | Sprache | Events zitieren
LabKey-Fehler | HTTP-Body | Retry vorschlagen
GEO/PRIDE-Meta | Accession | P-GEO-META
[/TABLE]


## 18.2 Verboten
Discard/Ship/Lock ohne Mensch.
ELN-Signatur.
Rechte ändern.
PHI in Prompts.
SQL/Shell außerhalb der Tools.

## 18.3 Kanäle und Prompts
UI-Chat mit Session gegen lokalen MCP.
Externe Assistenten: API-Key, POST /mcp.
Batch-Worker: Service-Account, Ergebnisse in Review-Queue.
osm.intake_assistant  —  create nach confirm.
osm.sop_job  —  Template-JSON.
osm.finder_nl  —  Sprache nach DSL.
osm.eln_scribe  —  weigert sich bei signed.
osm.audit_explain  —  nur lesen.
Maximal eine unsichere Schreibkette pro Turn. RAG nur auf SOPs, Templates, Schemata; nicht auf PHI-ELN oder USB-Dateien. Injection in SOP-PDF darf keine Extra-Tools freischalten.

# 19. Entscheidungsprotokoll
Freezer-Map, Job-Queue, ELN und Finder haben eigene Abnahmen. LabKey CE wird über §16-Module und P-LK-* bedient. LLMs nur über MCP mit Bestätigung. Die Spezifikation ist implementierungsreif.

## There is no pre-built or official integration between Hugging Face LLMs and LabKey Community Edition.
Combining them requires custom development using LabKey’s extensibility features (client APIs, scripting engines, modules, and pipelines) together with Hugging Face’s libraries, Inference API/Endpoints, or local model serving. LabKey Community Edition (CE) is a free, open-source scientific data management system (Apache 2.0) focused on structured data, assays, studies, samples, security, and collaboration. Hugging Face provides models, the Transformers library, huggingface_hub, Inference Providers/API, and endpoints for running LLMs (and other models).
github.com
LabKey’s newer AI-oriented features (MCP/Model Context Protocol Server for connecting external AI agents, in-product AI assistants, etc.) are premium-only (Professional/Enterprise editions) and unavailable in CE.
labkey.org
CE still supports the building blocks needed for integration: Python/R/JavaScript client APIs, configurable scripting engines (Python, R, Perl), transform scripts, script pipelines, file-based custom modules, and role-restricted API keys.
github.com +1
Feasible Integration Approaches (Community Edition)1. External Python Scripts / Applications (Easiest Starting Point)Use the official LabKey Python client (pip install labkey) alongside Hugging Face libraries.
Query, filter, or export data from LabKey schemas/tables/lists/assays via APIWrapper / select_rows / execute_sql.
Process with Hugging Face:
transformers + torch (or accelerate) for local inference.
huggingface_hub.InferenceClient or direct HTTP calls to the free Inference API / paid Inference Endpoints / third-party providers.
Embeddings, text generation, summarization, classification, NER, or domain-specific models (biomedical, protein, scientific literature, etc.).
Write results back to LabKey (new lists, datasets, assay runs, or files via WebDAV).
Authenticate LabKey with an API key (preferably role-restricted, e.g., Reader or Editor-without-Delete). Use a Hugging Face token for the Hub/Inference.
This works from any machine that can reach the LabKey server. Ideal for batch jobs, notebooks, scheduled scripts, or a separate microservice (FastAPI/Flask) that LabKey users can call.2. LabKey-Native Scripting (Transform Scripts, R/Python Reports, Script Pipelines)Configure a Python (or R) scripting engine on the LabKey server (Admin Console → Views and Scripting).
labkey.org
Transform scripts (attached to assay designs): Pre- or post-process uploaded data with an LLM (e.g., clean text fields, generate annotations, detect anomalies).
Reports: Create Python/R reports on data grids that call Hugging Face models and render tables/plots/text.
Script pipelines: Chain tasks (Python → R → insert results) for automated workflows. Supported languages include Python, R, and Perl.
labkey.org
Caveats:
The simple official Docker CE image deliberately disables OS-level R/Python scripting integrations. Use a full OS install, VM, or custom Docker setup.
github.com
Heavy local LLM inference is usually impractical on the LabKey application server (resource contention, GPU needs). Prefer remote Hugging Face Inference Endpoints or a dedicated inference server.
Scripts run with the permissions of the configured engine user; secure API keys carefully.
3. Custom Modules (File-Based or Java)Develop a file-based module (no compilation required) containing:
Queries, views, web parts, HTML/JS pages that call the Hugging Face Inference API via JavaScript (@huggingface/inference or fetch).
Python/R reports or pipeline definitions that invoke models.
Optional Java code for deeper server-side actions.
Deploy the .module file; enable it in the desired folders. This is the cleanest way to embed LLM features directly into the LabKey UI.
labkey.org
4. Hybrid / Service-Oriented
Stand up a separate inference service (Hugging Face Endpoints, vLLM, TGI, Ollama, etc.) that exposes an HTTP API.
LabKey calls it via transform scripts, external modules, or a custom web part.
Use LabKey’s HTTP interface or client APIs for bidirectional data flow.
Optional: Build a lightweight frontend (or use LabKey’s existing grids) that talks to both systems.
Practical Considerations and Limitations
Resources & Performance: LLMs are compute-heavy. Cloud Inference Endpoints or a dedicated GPU box is almost always better than running models inside the LabKey JVM/process. Free Hugging Face Inference API has rate limits and cold starts; paid endpoints or self-hosted solutions scale better.
Data Privacy & Security: LabKey CE has strong permissioning and audit logs. Never send PHI/sensitive data to public Hugging Face endpoints without proper agreements or local models. Use role-restricted LabKey API keys. Keep Hugging Face tokens out of source control.
Model Choice: Hugging Face hosts many relevant models (scientific literature summarization, biomedical NER, protein language models, general instruction-tuned LLMs, embedding models for semantic search over LabKey text fields, etc.).
CE vs Premium: CE gives you full APIs and scripting; Premium adds MCP (so an external agent powered by a Hugging Face model could query LabKey more naturally), managed AI features, better support, and additional modules.
Installation Reality: Full scripting support requires a properly configured LabKey server (Linux recommended). The quick-start Docker CE is mainly for evaluation of core data features.
Development Effort: Expect custom code for data mapping, prompt engineering, error handling, result storage, and UI. Start with a simple external Python script that pulls one table, runs a small model, and inserts a summary list.
Recommended Starting Path
Install/set up LabKey CE (full install if you need scripting).
Generate a LabKey API key and a Hugging Face token.
Write a small Python script using labkey + huggingface_hub / transformers that demonstrates the round-trip (query → LLM → insert).
Move the logic into a LabKey Python report or transform script once it works.
Package as a file-based module for reusable UI/web parts if needed.
For production scale, move inference to dedicated endpoints or a local serving stack and keep LabKey as the data/governance layer.
This approach leverages LabKey’s strengths (structured, permissioned, auditable scientific data) with Hugging Face’s model ecosystem without requiring premium licenses. The integration is entirely custom but fully achievable with the open tools both platforms already provide. If you have a specific use case (e.g., assay text summarization, natural-language querying of studies, embedding-based search, or a particular model family), more concrete architecture or code sketches can be developed from there.