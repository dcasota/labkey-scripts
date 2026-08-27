# Feature Requirement Document (FRD): Assistant Support

**Feature ID**: FRD-011
**Feature Name**: Assistant support that cannot act unsupervised
**Related PRD Requirements**: REQ-11, REQ-14, REQ-15
**Memory Requirements**: FR-045, FR-046, FR-065, FR-066, FR-067, CON-010, CON-011, CON-012, PRO-005, PRO-006, PRO-007, PRO-008, PRO-009
**Spec Sections**: §10, §18, §18.1, §18.2, §18.3
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

Assistants read and propose freely, and write only with explicit confirmation and
an administrative scope. Every invocation is audited with the model and request
identity. At most one unsafe write chain per turn.

### Value Proposition

The tasks assistants are genuinely good at here — mapping a messy CSV onto sample
fields, drafting a job template from an SOP, turning a sentence into a finder
filter, finding a free slot — are all *proposals*. A human confirms them in one
click. Nothing about that workflow requires the assistant to hold write authority,
and giving it any is the failure mode this document exists to prevent.

### Success Criteria

- The five prohibited operations — discard, ship, lock, sign, change permissions
  — are **not exposed as tools at all**, proven by a test that inspects the tool
  list (REQ-14).
- A hostile SOP PDF cannot obtain a tool the session did not already have.
- Every LLM call appears in the audit trail with its model and request id.
- Every agent-initiated write is distinguishable from a human one in the trail.

---

## 2. Functional Requirements

### 2.1 LLMs act only through MCP tools (FR-064)

**Description**: No domain action without a tool; no SQL or shell outside the
declared tools (PRO-009).

**Acceptance Criteria**: the MCP server exposes no generic query tool, no SQL
passthrough, no filesystem access (FRD-009 §2.4). The tool surface is the whole
surface.

### 2.2 Capabilities that are absent, not refused (REQ-14)

**Description**: An assistant may never discard, ship or lock a sample without a
human (PRO-005), may never sign an ELN entry (PRO-006), and may never change
permissions (PRO-007).

**Acceptance Criteria**:
- These are **not tools**. A capability that must never be reachable is better
  absent than refused at call time.
- The test asserts absence from the tool list — not that calling them returns
  403, because a refusal implies a code path that a future change could weaken.

### 2.3 Confirmation and scope for destructive actions (FR-045)

**Description**: Destructive actions require `confirm=true` **and** the
`osm.admin.write` scope.

**Acceptance Criteria**:
- Both conditions, not either. A confirmation without the scope fails; the scope
  without a confirmation fails.
- The confirmation is a fresh, explicit act by a human in that turn — not a
  standing preference, not a default.
- The action still passes every ordinary check: role, lifecycle gate, RLS. The
  scope adds nothing beyond permitting the class of call.

### 2.4 One unsafe write chain per turn (CON-010)

**Description**: At most one unsafe write chain per turn.

**Acceptance Criteria**:
- The limit is counted server-side, per session turn, not enforced by prompting.
- A second unsafe chain in the same turn is refused with an explanation, and the
  refusal is audited.

**Edge Cases**: a chain that fails partway (it still counts — otherwise a failing
first attempt would unlock a second); a batch worker (FR-067) whose whole run is
one turn.

### 2.5 Audit of every invocation (FR-065, FR-046)

**Description**: Every LLM call emits `llm.invoke` recording `model_id` and
`request_id`. Agent-initiated writes carry `actor_type=mcp`.

**Acceptance Criteria**:
- The event is emitted for reads as well as writes — the question "what did the
  assistant see" must be answerable.
- `actor_type=mcp` distinguishes agent actions from human actions in the trail
  (FRD-007 §2.2), so an audit can separate them without heuristics.
- **No PHI in prompts** (PRO-008): the prompt is not stored verbatim in the audit
  event; the event records model, request id, tool names and outcome.

### 2.6 The retrieval corpus is restricted at index time (CON-011)

**Description**: The RAG corpus contains SOPs, templates and schemas. It does
**not** contain PHI-bearing ELN content or USB files.

**Acceptance Criteria**:
- The restriction is applied **at index time**, not as a query-time filter. A
  filter can be bypassed; an absent index cannot.
- A test asserts that indexing a notebook is not merely skipped but impossible
  through the indexing entry point.

### 2.7 Prompt injection cannot unlock tools (CON-012)

**Description**: Injection in an SOP PDF must not unlock extra tools. The tool
allowlist is **bound to the session at authentication time**, never to document
content.

**Acceptance Criteria**:
- The allowlist is frozen in the MCP session binding (FRD-009 §3) before any
  document is read.
- The adversarial test is explicit: a document containing an instruction to
  enable a tool, retrieved into context, changes nothing.
- This is the most likely arrival path for a hostile document, because SOPs and
  templates are in the corpus **by design** (§2.6).

### 2.8 Assistant use cases (FR-066)

CSV intake mapping, SOP → template drafting, natural-language finder, free-slot
lookup, **queue prioritisation (read-only)**, ELN drafting, assay interpretation.

**Acceptance Criteria**:
- Every one produces a **proposal** that a human accepts. The natural-language
  finder emits a typed filter validated by the ordinary parser (FRD-006 §2.5);
  ELN drafting reaches `osm.eln.append_ref`, which is **draft only** (FR-044).
- Queue prioritisation is read-only — it may not reassign or complete a task
  (FRD-004 §7).

*Priority: should, iteration I6.*

### 2.9 Three channels (FR-067)

| Channel | Identity | Notes |
| --- | --- | --- |
| UI chat | the logged-in user, against the local MCP | inherits that user's role |
| External assistant | API key on `POST /mcp` | cannot exceed the key's role |
| Batch worker | service account | writes into a **review queue**, not into the domain |

**Acceptance Criteria**: the batch channel's output lands in a review queue for a
human, so an unattended run cannot commit domain state directly.

---

## 3. Data Requirements

`McpSession` (session, identity, **frozen tool allowlist**, turn counter,
created_at) and `AssistantProposal` (channel, proposal payload, status,
reviewed_by) for the batch review queue. The RAG index is a separate store whose
**ingestion path** is restricted by §2.6 — the restriction is a property of the
writer, not a column on the reader.

---

## 4. User Interface Requirements

Assistant surfaces appear inside the existing areas rather than as a separate
one: a chat panel, an accept/reject control on every proposal, and a visible
indication when a proposal would perform a write. The confirmation for a
destructive action names what will change, and is not pre-checked (NFR-007: the
control must be reachable and legible by keyboard and screen reader).

---

## 5. Performance Requirements

Assistant latency is not bound by NFR-003 — an LLM call is not an API call. But
the tool calls it makes **are**, and each must meet the ordinary budget. A
proposal that issues fifty tool calls is a design problem, not a latency
allowance.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Tool not in the session allowlist | refused; audited as an attempt |
| Destructive call without `confirm=true` | refused, naming the requirement |
| Destructive call without `osm.admin.write` | refused, naming the scope |
| Second unsafe write chain in a turn | refused (CON-010), audited |
| Underlying REST call fails | the REST status and reason pass through unchanged |
| Model unavailable | the feature degrades to manual; no domain path depends on it |

A refused tool call is an ordinary outcome and must be audited, not swallowed —
attempted misuse is exactly what a trail is for.

---

## 7. Security Requirements

**Who may write.** An assistant writes only as the identity it authenticates as,
and only through tools that exist. Destructive classes need `confirm=true` plus
`osm.admin.write` (FR-045). The batch channel writes to a review queue only.

**Audit events emitted**: `llm.invoke` (model, request id, tools used),
`mcp.tool_called`, `mcp.tool_refused`, plus the ordinary feature event for any
write, carrying `actor_type=mcp` (FR-046).

**The five prohibitions**, each enforced by absence rather than refusal:
discard/ship/lock (PRO-005), ELN signature (PRO-006), permission change
(PRO-007) — no tool exists. Plus **no PHI in prompts** (PRO-008) and **no SQL or
shell outside the declared tools** (PRO-009).

**Injection surfaces** — this feature is defined by one of them. *Prompt
injection*: the allowlist is bound at authentication time and never derived from
document content (CON-012); the corpus is restricted at index time (CON-011).
Everything an assistant submits then crosses the ordinary boundaries — typed
filters (FRD-006), validated file imports (FRD-001), bounded barcodes (FRD-003) —
because a proposal is untrusted input like any other.

**Content-derived privilege is impossible by construction** (REQ-15): there is no
code path from document text to capability. That is a structural claim and it is
tested adversarially, not assumed.

---

## 8. Dependencies

### Depends On
- FRD-009 (REST and MCP) — the tool surface and the session binding.
- FRD-007 (audit), FRD-008 (identity, roles, scopes).
- ADR-0006 (MCP as a thin adapter) — an assistant cannot exceed its role because
  the adapter has nothing else to reach.

### Depended On By
- Nothing. Every assistant capability is additive; removing this feature removes
  convenience and no domain function.

---

## 9. Open Questions

1. **Which model, and hosted where?** `HUGGINGFACE_API_KEY` and
   `HUGGINGFACE_MODEL_ID` are reserved in `.env.example` and read by no code. A
   hosted model receiving lab data is a data-protection question (CON-007's DPIA
   posture) that no requirement answers.
2. What exactly is an "unsafe write chain"? CON-010 bounds it to one per turn but
   does not define its boundaries — a single tool call, or a sequence?
3. Do the three channels share one tool list (FRD-009 §9.3)?
4. Is a proposal retained after rejection, and for how long? Useful for
   evaluating the assistant; a retention question either way.

---

## 10. Non-Functional Requirements

**CON-010** (one unsafe write chain per turn), **CON-011** and **CON-012** are
the binding constraints, and all three are properties to be tested adversarially
rather than reviewed. AGENTS.md §3 lists prompt injection among the injection
surfaces "all of which appear in this project" — this is the feature where it
appears. Determinism does not apply to model output; it applies to the
**boundary**, which must behave identically no matter what the model emits.
