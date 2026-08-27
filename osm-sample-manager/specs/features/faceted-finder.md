# Feature Requirement Document (FRD): Faceted Finder

**Feature ID**: FRD-006
**Feature Name**: Faceted search across samples, lineage, storage and assays
**Related PRD Requirements**: REQ-6
**Memory Requirements**: FR-006, FR-039, NFR-002, CON-015
**Spec Sections**: §1, §8
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Facets over sample properties, **ancestor** properties, storage location and
assay thresholds, with counts, fast enough to browse at a million samples.
Filter expressions are parsed into a typed structure and never concatenated into
SQL.

### Value Proposition

The queries that matter are the ones that cross boundaries: *plasma aliquots
derived from a source collected before March, currently in freezer B, whose
assay value exceeds a threshold.* Each half of that is easy; the combination is
what people currently do by exporting three spreadsheets. Facets with counts make
it interactive — you can see that a filter would return nothing before applying
it.

### Success Criteria

- P95 under 300 ms at one million samples (NFR-002).
- Ancestor facets work at least six generations up without an N+1 explosion.
- A hostile filter expression cannot reach the SQL text. Proven by tests that
  attempt injection, not by inspection.
- Counts agree with the result set they describe.

---

## 2. Functional Requirements

### 2.1 Facet dimensions (FR-039)

**Description**: Four dimensions of facet.

| Dimension | Examples |
| --- | --- |
| Sample properties | type, status, custom fields, expiry, amount range |
| Ancestor properties | source type, a parent's field value, generation depth |
| Storage location | site, device, rack, box; and "currently checked out" (FR-073) |
| Assay thresholds | a run's measured value above/below/between |

**Acceptance Criteria**:
- Each facet reports a **count** alongside each value.
- Selecting a facet value narrows the others' counts consistently — the counts
  describe the result set as filtered by everything else selected.
- Status is available as a facet and, in the lineage view, as a graph filter
  (FR-079, FRD-002 §2.4).

**Edge Cases**: a facet over a field that was archived (values remain
searchable, the facet is marked archived); a numeric facet on a field with mixed
units (grouped by unit, never summed across units).

### 2.2 Typed filter expressions (FR-006)

**Description**: A filter arrives as a structure — field, operator, typed value,
boolean composition — not as a string to be spliced into a query.

**Acceptance Criteria**:
- The parser accepts only declared fields, declared operators and values that
  match the field's type. Anything else is rejected at the boundary with 422.
- **No filter component is ever concatenated into SQL.** Parameters are bound.
- The expression is representable as JSON so a saved search is data.

**Edge Cases**: an expression referencing a field the caller may not read
(rejected as unknown field — the same response as a genuinely unknown field, so
the error does not disclose the schema of another project); deeply nested boolean
composition (bounded depth, rejected beyond it).

### 2.3 Result set and pagination

**Acceptance Criteria**:
- Results are paginated with a stable sort, so page 2 does not repeat page 1's
  last row.
- Rows the caller may not read are **absent from both the results and the
  counts** (CON-015). A count that includes invisible rows is a disclosure.
- Export of a result set is available and audited as a read event.

### 2.4 Indexing (P-REINDEX)

**Description**: Facet performance depends on an index that is maintained as
samples change; reindexing is an operations pipeline (FR-063, FRD-012).

**Acceptance Criteria**:
- Reindexing is idempotent and re-runnable (AGENTS.md §4).
- A reindex in progress does not serve partial results as if complete.

### 2.5 Natural-language finder (assistant)

**Description**: An assistant may translate a natural-language question into a
typed filter expression (FR-066).

**Acceptance Criteria**:
- The assistant produces the **typed structure**, which is then validated by the
  same parser as any other filter. It does not produce SQL.
- No SQL or shell access exists outside the declared tools (PRO-009).
- The proposed filter is shown to the user before it runs.

---

## 3. Data Requirements

The finder reads the registry, storage and assay tables; it owns a
search index (denormalised projection) plus `SavedSearch` (owner, name,
expression JSON). Row-level security applies to the underlying tables, and the
index is either RLS-protected too or filtered through an RLS-protected view —
**an index that bypasses RLS is a disclosure channel** and fails review.

---

## 4. User Interface Requirements

The **Finder** area (FR-048): facet rail with counts, result grid, saved
searches, and export. Facet counts must be legible to a screen reader as counts,
not as decoration (NFR-007).

---

## 5. Performance Requirements

- **NFR-002: P95 under 300 ms at one million samples.** This is the binding
  number and the reason the projection exists.
- Ancestor traversal is set-based (recursive CTE or a materialised closure), not
  per-row.
- Facet counts are computed with the result set, in one pass, not by issuing one
  count query per facet value.
- 100 concurrent users (NFR-004) browsing facets must not serialise on the index.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Unknown or unreadable field in a filter | 422, "unknown field" — identical for both |
| Value that does not match the field type | 422, naming field and expected type |
| Boolean nesting beyond the bound | 422, naming the bound |
| Reindex in progress | results served from the last complete index, with a freshness marker |
| Query exceeding a time budget | 503 with a retry hint, never an open-ended hang |

---

## 7. Security Requirements

**Who may write.** Nothing in this feature writes domain data. Saved searches are
written by their owner; a shared saved search is written by Project admin.
Reindexing: Project admin, or the scheduled operations pipeline. Reader may
search. Auditor may read the trail and nothing else (CON-006).

**Audit events emitted**: `search.exported` (an export is a bulk read and is
recorded), `search.saved`, `search.index_rebuilt`. Ordinary interactive searches
are **not** individually audited — read-access auditing was flagged as
questionable scope in the premium-feature harvest and is listed in §9 as an open
question rather than assumed.

**Injection surface — LabKey SQL and OSM SQL.** This is the feature the AGENTS.md
warning is about: *never build a query by string concatenation from user input;
parse filter expressions into a typed structure*. LabKey SQL supports `USERID()`,
`||`, `COALESCE`, joins and subqueries, all of which a hostile filter could
exploit if it reached the query text. The parser is the boundary, and it is
server-side; client-side validation is a convenience only.

**Cross-boundary disclosure (CON-015).** LabKey took both available positions
here and OSM takes the stricter one: results, counts, facet values and ancestor
nodes must not disclose the name, id or existence of an object the caller may not
read. A facet value that exists only in another project must not appear even with
a count of zero.

**Assistant boundary**: the natural-language finder proposes a typed filter and
never SQL (PRO-009); the tool allowlist is bound at authentication time and never
derived from document content (CON-012).

---

## 8. Dependencies

### Depends On
- FRD-001 (samples, lineage), FRD-003 (storage location), FRD-008 (RLS — the
  finder is where a policy gap would show first).
- FRD-012 (operations) owns P-REINDEX.

### Depended On By
- FRD-001 (picklists are built from finder results), FRD-004 (a job can start
  from a finder result set), FRD-011 (the assistant's read path).

---

## 9. Open Questions

1. **Should interactive reads be audited?** OSM audits writes. The premium-gap
   analysis flags read-access auditing as a capability LabKey's paid tiers have
   and OSM has not specified. For a system holding tokenised study data this may
   be required; it is a compliance decision, not an implementation one.
2. Saved searches were flagged as questionable scope in the harvest — are they in
   for I5, or later?
3. Is there a maximum export size, and is a large export a job rather than a
   request?

---

## 10. Non-Functional Requirements

NFR-002 (P95 < 300 ms at 1e6), NFR-004 (100 concurrent users), NFR-005 (one
million samples), NFR-007 (WCAG 2.2 AA). **CON-014** gives the finder an
independent acceptance; CON-013 sets the I5 gate as "Search done **with RLS**" —
the RLS is part of the acceptance, not a follow-up.
