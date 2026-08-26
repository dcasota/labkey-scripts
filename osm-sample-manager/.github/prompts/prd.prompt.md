---
agent: pm
---
# Dev team flow step

Create or revise the Product Requirements Document.

## Input

- `specs/source/spezifikation-extract.md` — the extracted source specification.
- The memory database — 97 requirements already extracted, with their spec
  section references: `tools/memory.py list requirements --brief`.

## Output

`specs/prd.md`, using exactly this skeleton:

```markdown
# Product Requirements Document (PRD)

## 1. Purpose

## 2. Scope
### In Scope
### Out of Scope

## 3. Goals & Success Criteria
### Goals
### Success Criteria

## 4. High-Level Requirements
### Core Capabilities
- **[REQ-1] Title**
  - detail
  - detail

## 5. User Stories
### Theme
```gherkin
As a [role], I want to [do something], so that [benefit].
```

## 6. Assumptions & Constraints
### Assumptions
### Constraints
```

Close with a `**Document Version:** / **Last Updated:** / **Status:**` block.

## Rules

- Every `REQ-n` must roll up one or more memory requirement ids, and must be
  traceable to a spec section. State the mapping in the REQ bullet.
- The prohibitions in §16.2 and §18.2 are requirements. They belong in §4 as
  negative capabilities, not as footnotes.
- No technology choices, no schemas, no API shapes. That is `@architect`'s work.
- This is a living document. Revise it when the spec understanding changes.
