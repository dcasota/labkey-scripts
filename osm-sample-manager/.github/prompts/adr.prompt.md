---
agent: architect
---
# Dev team flow step

Record an architecture decision.

## Output

`specs/adr/NNNN-<short-kebab-title>.md`, 4-digit zero-padded, next sequential
number. Never reuse a number.

```markdown
# ADR-NNNN: Title In Title Case

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded

## Context

## Decision Drivers

## Considered Options
### Option 1: Name
**Description**:
**Pros**:
**Cons**:
### Option 2: Name
### Option 3: Name

## Decision Outcome
**Chosen Option**: Name
**Rationale**:

## Consequences
### Positive
### Negative
### Neutral

## Implementation Notes

## References
```

## Quality gates

Must have: at least three considered options; a clear rationale; both positive
and negative consequences; sequential numbering; links to the PRD/FRD sections
and memory requirement ids it serves.

Avoid: a single option; vague consequences; implementation code; duplicating an
existing ADR.

## Then

Mirror it into the memory database so it is queryable next to the requirements:

```bash
tools/memory.py add decision --id ADR-NNNN --title "..." --status accepted \
    --context "..." --decision "..." --consequences "..." --alternatives "..."
```
