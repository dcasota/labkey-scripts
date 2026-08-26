# Standard: verify, do not assume

## Rule

No claim about the behaviour of an external system may be stated in code, a
comment, a document or a decision record without evidence, recorded in the
memory database.

## Evidence, strongest first

1. **`source`** — the LabKey sources under `/root/scicore`. Cite an absolute
   file path and the identifier or line range.
2. **`http`** — a real call against the running server. Cite the action and the
   observed response.
3. **`shell`** — a command and its output, for host facts.
4. **`doc`** — official documentation, cited by URL. Weakest, because
   documentation and implementation diverge; `docs/gap-analysis.md` records
   several cases where they do.

`reasoning` is never acceptable evidence for a behavioural claim.

## Recording

```bash
tools/memory.py add verification --id V-nnn --claim "one sentence" \
    --method source --command "what you ran or read" \
    --result pass|fail|partial --detail "what you observed"
```

Durable knowledge additionally becomes a research row:

```bash
tools/memory.py add research --id RF-nnn --topic "..." --finding "..." \
    --evidence-kind source --evidence-ref /root/scicore/...
```

## Review checks

- A pull request asserting new external behaviour without a verification row
  fails review.
- A verification whose `result` is `fail` must not be deleted. Negative results
  are why the register exists.
- Verification runs read-only unless the claim requires a write. A write goes to
  a scratch container this project owns and is cleaned up.
