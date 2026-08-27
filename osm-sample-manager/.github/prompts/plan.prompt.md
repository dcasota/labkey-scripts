---
agent: dev
---
# Dev team flow step

Decompose the FRDs into implementable tasks and an ordered pull-request backlog.

## Output

1. `specs/tasks/NNN-task-<slug>.md`, one per task, 3-digit zero-padded.
2. `specs/tasks/README.md` — the phase index and the Feature-to-Task mapping.
3. The same backlog in the memory database, so it can be queried and its status
   tracked: `tools/memory.py add backlog ...` and `tools/memory.py add task ...`.
4. `docs/backlog.md` — a rendering of the memory backlog for humans.

## Task file template

```markdown
# Task NNN: Title

**Feature**: <Feature Name> (FRD-NNN)   — or `Infrastructure` for scaffolding
**Dependencies**: Task 001 (Name), Task 004 (Name)
**Estimated Complexity**: Low | Medium | High | Very High

---

## Description

---

## Technical Requirements

---

## Acceptance Criteria
- [ ] measurable, checkable

---

## Testing Requirements
### Unit Tests
### Integration Tests

---

## Implementation Notes

---

## Definition of Done
- [ ] ...
```

Complexity vocabulary: Low 1–2 days, Medium 3–5 days, High 5–10 days,
Very High 10+ days.

## Critical rules

- **Always create scaffolding tasks before any feature task.** Scaffolding must
  be complete before feature work begins.
- **No implementation code in a task file.** Describe what, not how.
- Every task names its dependencies explicitly, and every dependency must exist.
  `tools/memory.py check` enforces this.
- A pull request must be small enough to review in one sitting. If acceptance
  criteria exceed roughly ten checkboxes, split it.
- Order the backlog so that each item is independently mergeable and leaves the
  tree green.
