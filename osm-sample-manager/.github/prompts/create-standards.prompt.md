---
agent: architect
---
# Dev team flow step

Generate the engineering standards this project holds itself to.

Run after the ADRs are written and before `/generate-agents`, which synthesises
these files into `AGENTS.md`.

## Output

```
standards/general/          language-agnostic practice
  git-workflow.md           branching, commit messages, pull request process
  security.md               secrets, least privilege, validation, injection
  testing.md                what must be tested and to what depth
  verification.md           the verify-do-not-assume rule
standards/backend/          Python service conventions
standards/frontend/         TypeScript UI conventions
standards/labkey/           the rules for talking to a LabKey server
```

Each file states rules that can be checked, not aspirations. A rule that cannot
fail a review is not a standard.
