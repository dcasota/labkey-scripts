# ADR-0006: The MCP Server Is A Thin Adapter Over The REST API

**Date**: 2026-08-26
**Status**: Accepted

## Context

§10 lists MCP tools alongside REST endpoints and states that the tools *are*
REST semantics (`osm.samples.*`, `osm.storage.*`, `osm.jobs.*`,
`osm.eln.append_ref`, `osm.audit.for_entity`, `osm.labkey.publish_status`).
§8 says `MCP a UI` — the UI is a client of the same surface. §18 says LLMs act
only through MCP tools and that no domain action happens without a tool.
§18.2 forbids specific actions outright. §18.3 caps unsafe write chains at one
per turn and requires that prompt injection in an SOP PDF cannot unlock extra
tools.

The risk is that the MCP server becomes a second, subtly different door into the
domain — one with its own authorisation logic that drifts from the REST path.
That is how an agent ends up able to do something a user cannot.

## Decision Drivers

- §18 makes MCP an *agent-facing* surface, so its authorisation must be at least
  as strict as the human-facing one, never looser.
- CON-005 forbids a privileged back door for the UI, which generalises: there is
  one authorisation implementation, not one per transport.
- §18.2's prohibitions must be enforced where they cannot be argued around.
- §10 requires `actor_type=mcp` in the audit, so the transport must be visible
  to the audit layer even though the logic is shared.

## Considered Options

### Option 1: MCP server with its own domain access

**Description**: The MCP server imports the domain services directly and calls
them, in-process.

**Pros**:
- Lowest latency; no HTTP hop.
- Full access to rich domain types.

**Cons**:
- Two authorisation paths that must be kept identical by discipline. They will
  drift, and the drift will be discovered by an agent doing something it should
  not.
- Bypasses the request validation layer that the HTTP boundary applies.
- Makes §18.2's prohibitions a property of MCP-server code rather than of the
  domain.

### Option 2: MCP server as an HTTP client of the REST API

**Description**: Each MCP tool is a thin translation of arguments onto a REST
call, authenticated as the agent's principal.

**Pros**:
- Exactly one authorisation implementation, at the REST boundary.
- An agent structurally cannot do anything a user with the same role cannot.
- Validation, rate limiting and audit all apply unchanged.
- §10's "tools = REST semantics" becomes literally true.

**Cons**:
- An HTTP hop of added latency per tool call.
- Errors must be translated back into a form an agent can act on.

### Option 3: Shared service layer, two thin transports

**Description**: Domain services expose one API; both the REST router and the
MCP server are thin transports over it, sharing the authorisation decorator.

**Pros**:
- No HTTP hop.
- One authorisation implementation, if the decorator is genuinely shared.

**Cons**:
- "If the decorator is genuinely shared" is the whole risk, and it is enforced
  only by review.
- Agent-specific rules (§18.2's prohibitions, §18.3's one-unsafe-chain cap) have
  no natural home; they end up in the MCP transport, which is where Option 1's
  drift problem returns.

## Decision Outcome

**Chosen Option**: Option 2 — MCP as an HTTP client of the REST API.

**Rationale**:

- The threat model is an adversarial agent, possibly one steered by injected
  text in an SOP PDF (§18.3). Against that, a structural guarantee that the
  agent's door is the same door beats a reviewed convention.
- The latency cost is a loopback HTTP call, which is negligible against §14's
  200 ms budget and is paid only by agent traffic.
- It gives §18.2's prohibitions a natural home: they are additional constraints
  applied to the agent's *principal*, so they hold no matter which tool is
  called and no matter what a document told the agent to do.

## Consequences

### Positive

- An agent cannot exceed the role it authenticates as, by construction.
- Every agent action passes the same validation and emits the same audit event,
  tagged `actor_type=mcp` per §10.
- §18.3's injection requirement is satisfiable: the tool allowlist is bound to
  the session at authentication time and is not derived from any content the
  agent reads. Document text can ask for a tool, but the allowlist is not
  listening.

### Negative

- One extra network hop per tool call.
- The MCP layer must translate HTTP errors into agent-actionable messages
  without leaking information the principal may not see.

### Neutral

- The UI is a peer of the MCP server, both being HTTP clients. This is what §8's
  `MCP a UI` asks for.

## Implementation Notes

- Destructive tools require `confirm=true` **and** the `osm.admin.write` scope
  (§10). The confirmation is a second, explicit argument, so a model cannot
  satisfy it by accident while summarising a document.
- §18.2's absolute prohibitions — discard, ship, lock, ELN signature, permission
  changes — are not exposed as MCP tools at all. A capability that must never be
  reachable by an agent is best not present in the tool list; refusing at call
  time is a weaker guarantee than not existing.
- Every tool invocation emits `llm.invoke` with `model_id` and `request_id`
  (§18), correlated with the resulting domain audit event.
- The RAG corpus is restricted to SOPs, templates and schemas (CON-011). PHI-
  bearing ELN content and USB files are excluded at index time, not filtered at
  query time.

## References

- `specs/source/spezifikation-extract.md` §8, §10, §14, §18, §18.2, §18.3
- Memory: `FR-008`, `FR-044`, `FR-045`, `FR-046`, `FR-064`, `FR-065`,
  `FR-067`, `CON-005`, `CON-010`, `CON-011`, `CON-012`,
  `PRO-005`, `PRO-006`, `PRO-007`, `PRO-008`, `PRO-009`
