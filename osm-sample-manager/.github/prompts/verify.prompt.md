---
agent: dev
---
# OSM-specific step

Establish ground truth about the environment, and record it so no later session
has to guess.

This command exists because the project's hardest failure mode is a plausible
but wrong belief about what LabKey Community Edition does.

## Procedure

1. State the claim in one sentence.
2. Choose the strongest available evidence, in this order:
   - **`source`** — the Java/TypeScript sources under `/root/scicore`. Cite an
     absolute file path and the identifier.
   - **`http`** — an actual call against the running server via
     `scripts/labkey_client.py`. Cite the action and the observed response.
   - **`doc`** — official LabKey documentation. Cite the URL.
   Never accept `reasoning` as evidence for a behavioural claim.
3. Record it:

```bash
tools/memory.py add verification --id V-nnn --claim "..." \
    --method http --command "..." --result pass|fail|partial --detail "..."
```

4. If the finding is durable knowledge rather than a one-off check, also record
   it as research:

```bash
tools/memory.py add research --id RF-nnn --topic "..." --finding "..." \
    --evidence-kind source --evidence-ref /root/scicore/...
```

## Rules

- A `fail` result is as valuable as a `pass`. Record it; do not retry until you
  get the answer you wanted.
- Verification runs read-only unless the claim genuinely requires a write. A
  write goes to a scratch container the project owns, never to
  `SleepDrive-Lab`, and is cleaned up.
