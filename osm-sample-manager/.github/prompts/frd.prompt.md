---
agent: pm
---
# Dev team flow step

Break the PRD into Feature Requirement Documents.

## Input

`specs/prd.md` and the memory requirements.

## Output

One file per feature in `specs/features/`, named in descriptive kebab-case
(`sample-registry.md`, `freezer-map.md`). **Not numbered in the filename** — the
`FRD-NNN` id lives inside the document.

```markdown
# Feature Requirement Document (FRD): <Title>

**Feature ID**: FRD-NNN
**Feature Name**: <longer descriptive name>
**Related PRD Requirements**: REQ-3, REQ-4
**Memory Requirements**: FR-028, FR-029, NFR-001
**Spec Sections**: §5, §17.1
**Status**: Draft
**Last Updated**: YYYY-MM-DD

---

## 1. Feature Overview
### Purpose
### Value Proposition
### Success Criteria

---

## 2. Functional Requirements
### 2.1 <Capability>

**Description**:

**Inputs**:

**Outputs**:

**Acceptance Criteria**:

**Edge Cases**:

---

## 3. Data Requirements
## 4. User Interface Requirements
## 5. Performance Requirements
## 6. Error Handling
## 7. Security Requirements
## 8. Dependencies
### Depends On
### Depended On By
## 9. Open Questions
## 10. Non-Functional Requirements
```

## Rules

- Ask for confirmation before creating each file.
- `**Memory Requirements**` and `**Spec Sections**` are OSM additions to the
  reference template. They are mandatory — they are what makes the chain from
  the .docx to the code auditable.
- §7 Security Requirements is never empty. Name the roles that may perform each
  write, the audit event emitted, and the injection surface if the capability
  touches LabKey SQL, file import, or barcode input.
- Record the links: `tools/memory.py link --req FR-028 --kind feature --to FEAT-nnn`.
