# Feature Requirement Documents

One FRD per PRD core capability. `FRD-NNN` lives inside each document; the
filename is descriptive kebab-case, not numbered, per `.github/prompts/frd.prompt.md`.

| FRD | File | PRD | Iteration gate (CON-013) |
| --- | --- | --- | --- |
| FRD-001 | [sample-registry.md](sample-registry.md) | REQ-1, REQ-13 | I1 — registry done at aliquot |
| FRD-002 | [sample-lifecycle.md](sample-lifecycle.md) | REQ-2 | I1 |
| FRD-003 | [freezer-map.md](freezer-map.md) | REQ-3 | I2 — freezer map done per §5 |
| FRD-004 | [jobs-and-work-queue.md](jobs-and-work-queue.md) | REQ-4 | I3 — workflow done at queue |
| FRD-005 | [electronic-lab-notebook.md](electronic-lab-notebook.md) | REQ-5, REQ-14 | I4 — ELN done at signature |
| FRD-006 | [faceted-finder.md](faceted-finder.md) | REQ-6 | I5 — search done with RLS |
| FRD-007 | [tamper-evident-audit.md](tamper-evident-audit.md) | REQ-7 | I0 — done when the hash chain verifies |
| FRD-008 | [authorisation-and-rls.md](authorisation-and-rls.md) | REQ-8, REQ-15 | I0 |
| FRD-009 | [rest-api-and-mcp.md](rest-api-and-mcp.md) | REQ-9 | I0 (OpenAPI), I6 (MCP) |
| FRD-010 | [labkey-publishing.md](labkey-publishing.md) | REQ-10, REQ-13, REQ-16 | I6 — UI runs through the API |
| FRD-011 | [assistant-support.md](assistant-support.md) | REQ-11, REQ-14, REQ-15 | I6 |
| FRD-012 | [operations.md](operations.md) | REQ-12 | I7 |

Every FRD carries `**Memory Requirements**` and `**Spec Sections**` in its
header. Those two fields are OSM additions to the reference template and they are
what makes the chain from the specification `.docx` to the code auditable. Each
requirement named there also has a `file` traceability edge to the FRD that owns
it, so the chain is queryable:

```bash
tools/memory.py query "SELECT req_id, artifact_ref FROM traceability
                       WHERE artifact_kind='file' AND artifact_ref LIKE 'specs/features/%'"
```

## Coverage

108 of the 116 memory requirements are owned by an FRD. The remaining **eight are
deliberately not owned by any single feature** — they are cross-cutting and are
applied inside every FRD rather than specified in one:

| Requirement | Why it has no owning FRD |
| --- | --- |
| CON-001 | Licensing (Apache-2.0 / CC-BY-4.0) — repository-wide, see `LICENSE` |
| CON-002 | "Not a LabKey UI clone" — a constraint on all UI work, stated in ADR-0001 |
| FR-048 | The eight top-level UI areas — each FRD claims its own area in §4 |
| FR-056 | The uniform pipeline shape — every write pipeline in every FRD follows it |
| NFR-003 | API P95 < 200 ms — a budget every feature spends |
| NFR-004 | 100 concurrent users — likewise |
| NFR-005 | One million samples — likewise |
| NFR-007 | WCAG 2.2 AA — an obligation on every §4 |

Listing them here rather than force-fitting them into one document is the
honest option: an FRD that "owned" WCAG would not be where an implementer looks
for it.

## Status

Every document is **Draft**. None has been reviewed, and each carries a §9 Open
Questions section listing what must be decided before implementation. Several of
those are explicitly flagged as needing an ADR first — AGENTS.md §6.5: *if a
significant architectural decision is missing, stop; hand back for an ADR; do not
decide it inside the implementation.* The largest are:

- **FRD-005 §9.1** — what exactly is canonicalised before hashing a notebook.
  Without this, no signature is verifiable by a third party.
- **FRD-007 §9.1** — audit granularity for bulk writes: per row, or per batch.
  This must be settled before CSV import lands.
- **FRD-012 §9.1** — where backups live and who can read them. NFR-006 promises
  seven-day PITR; nothing yet says where the data sits.
- **FRD-008 §9.1** — whether "Storage/Workflow admin" is one role or two. The
  count of seven is stated twice, and two would be cleaner.
- **FRD-001 §9.1** — how pooling is modelled in `AliquotLink`.
- **FRD-004 §9.1** — the notification transport, which FR-035 requires and no
  requirement names.
