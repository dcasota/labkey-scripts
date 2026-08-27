# Feature Requirement Document (FRD): Electronic Lab Notebook

**Feature ID**: FRD-005
**Feature Name**: Electronic lab notebook with a binding signature
**Related PRD Requirements**: REQ-5, REQ-14
**Memory Requirements**: FR-005, FR-018, FR-037, FR-038, FR-060, FR-077, FR-078, CON-004, PRO-006
**Spec Sections**: §1, §3, §7, §17.2
**Status**: Draft
**Last Updated**: 2026-08-27

---

## 1. Feature Overview

### Purpose

A notebook moves draft → review → approved → signed → locked. Signing requires
fresh re-authentication and binds a canonical hash of the content to the signer.
A signed notebook is immutable and tampering with it is detectable. An amendment
creates a new revision without disturbing the signed one.

### Value Proposition

A signature is only worth something if it is attached to specific bytes. Scanning
a wet signature onto a PDF proves that someone signed *a* document; hashing the
canonical content and binding the hash to a freshly re-authenticated identity
proves which one. That difference is what makes the record admissible as
evidence rather than as a claim.

### Success Criteria

- Changing one character of signed content makes the stored hash disagree, and
  verification says so.
- No update path exists that can mutate a signed notebook — proven by a test that
  asserts the **absence** of the path, not merely a 403 (CON-004).
- Re-signing the same unchanged content yields the same hash; canonicalisation is
  deterministic.

---

## 2. Functional Requirements

### 2.1 The notebook state machine (FR-037)

**Description**: draft → review → approved → signed → locked, forward only, with
two declared backward moves for review (§2.4).

**Acceptance Criteria**:
- Transitions outside the declared set are refused with 409.
- A `signed` notebook accepts no content mutation by any route (CON-004).
- `locked` is terminal.

**Edge Cases**: an approver who is also the author (refused unless the project
permits self-approval, which is configuration and defaults to off); a notebook
whose referenced sample is deleted (impossible — samples are archived, not
deleted).

### 2.2 Notebook content and sample references (FR-018, FR-060 P-ELN-DRAFT)

**Description**: A notebook is structured content with references to samples,
jobs and assay runs.

**Acceptance Criteria**:
- References the reader may not see are omitted from the reference list entirely
  — not listed as inaccessible, which would disclose existence (CON-015).
- `Notebook` carries `status` and `hash`; the hash is null until signature.

### 2.3 Signature (FR-038, FR-060 P-ELN-SIGN)

**Description**: Signing canonicalises the notebook to JSON, hashes it, binds the
hash to the signer, locks the record and renders a PDF.

**Inputs**: notebook id, a **fresh** re-authentication, the attestation the signer
agrees to.

**Outputs**: `Notebook.hash`, signer identity, signature timestamp, attestation
text in force, a rendered PDF, and an audit event.

**Acceptance Criteria**:
- Re-authentication is **fresh** — a session token alone is not sufficient. The
  maximum age of the re-authentication is configuration with a conservative
  default.
- Canonicalisation is deterministic: key order, whitespace, number formatting and
  Unicode normalisation are all pinned, so the same content always hashes the
  same.
- The attestation wording is configurable per institution, and **the wording in
  force at signing time is stored with the signature** (FR-078) — not looked up
  later, when it may have changed.
- The signature event is written in the same transaction as the state change
  (FR-011, ADR-0003).

**Edge Cases**: re-authentication succeeds but the content changed in between
(the hash is computed after the lock, so the signed bytes are the locked bytes);
PDF rendering fails (the signature still commits — the PDF is a derived artefact
and is re-rendered, because losing a signature to a renderer is unacceptable).

### 2.4 Recall and return for changes (FR-077)

**Description**: The state machine supports two backward moves: a reviewer
returns a notebook for changes, and an author recalls one from review. Both are
recorded on a review timeline.

**Acceptance Criteria**:
- Neither move is available once the notebook is `signed`.
- Every backward move is audited with actor and reason (FR-070).

*Priority: should, iteration I4.*

### 2.5 Amendment after signature

**Description**: An amendment creates a **new revision** linked to the signed one.

**Acceptance Criteria**:
- The signed revision is untouched: same bytes, same hash, still verifiable.
- The amendment starts at `draft` and follows the full path to its own signature.
- The chain of revisions is navigable in both directions.

### 2.6 Tamper detection

**Description**: Verification recomputes the canonical hash and compares it.

**Acceptance Criteria**:
- Verification of an unmodified signed notebook passes; of a modified one, fails
  and names the notebook.
- Verification is available as an API call, not only a background job, so an
  auditor can ask on demand.

---

## 3. Data Requirements

| Entity | Key fields |
| --- | --- |
| `Notebook` | `notebook_id`, project, status, `hash`, revision_of, created_by |
| `NotebookSignature` | notebook, signer, signed_at, attestation_text, reauth_at |
| `NotebookReference` | notebook, target kind, target id |

`hash` is SHA-256 over the canonical JSON. `attestation_text` is stored per
signature (FR-078), not referenced. RLS on every table, keyed on project. The
signed row is protected additionally by a database rule: the audit tables grant
`INSERT`/`SELECT` and no `UPDATE`/`DELETE` (AGENTS.md §3), and the signed
notebook follows the same posture.

---

## 4. User Interface Requirements

The **ELN** area (FR-048): editor for drafts, review view with the timeline,
signing dialog that forces re-authentication and shows the attestation text
verbatim, and a read-only view of signed revisions with a visible verification
state. The attestation must be legible before the signer commits — not behind a
link (NFR-007).

---

## 5. Performance Requirements

Canonicalisation and hashing of a large notebook (hundreds of references,
embedded images by reference) must complete inside the API P95 budget
(NFR-003); if it cannot, signing becomes an explicit two-phase operation with a
progress record rather than a slow request.

---

## 6. Error Handling

| Condition | Response |
| --- | --- |
| Mutation of a signed notebook | **no such path**; if reached, 409 and an alert |
| Signature without fresh re-authentication | 401, naming the requirement |
| Stale re-authentication | 401, with the maximum age |
| Backward move on a signed notebook | 409 |
| Verification mismatch | 200 with an explicit `valid: false` plus an audit event |
| PDF render failure | signature commits; render is queued and reported |

A verification failure is **not** a 500. It is a truthful answer to a question
that was legitimately asked, and it must be recorded.

---

## 7. Security Requirements

**Who may write.** Draft and edit: Scientist, Project admin (the author).
Approve: Reviewer. **Sign: Reviewer only** (FR-047). Return for changes:
Reviewer. Recall: the author. Reader reads; Auditor reads the trail and nothing
else (CON-006).

**Audit events emitted**: `eln.created`, `eln.submitted_for_review`,
`eln.returned`, `eln.recalled`, `eln.approved`, `eln.signed`, `eln.amended`,
`eln.verified` — in the same transaction as the state change (FR-011, ADR-0003).
The `eln.signed` event carries the hash, the signer, the re-authentication time
and the attestation in force.

**Prohibition — assistants may never sign** (PRO-006). Signing is **not exposed
as an MCP tool at all**; a capability that must never be reachable is better
absent than refused at call time (REQ-14, FRD-011). The one notebook tool an
assistant has is `osm.eln.append_ref`, and it is **draft only** (FR-044).

**No PHI in prompts** (PRO-008): the RAG corpus is restricted **at index time**
to SOPs, templates and schemas — notebooks are excluded (CON-011). This is an
index-time restriction, not a query-time filter, because a filter can be
bypassed and an absent index cannot.

**Injection surfaces**: file attachments follow the import rules (declared
content type validated, size bounded); notebook text is stored and rendered as
text and never interpolated into SQL.

**Compliance note, from the harvest**: across sixty LabKey release-note pages,
"hash" and "tamper" appear **zero** times, and "21 CFR" appears once — as a
warning that skipping SAML re-authentication may *break* Part 11. There is no
prior art here to inherit and no compatibility to preserve; ADR-0003 and this
document are the design.

---

## 8. Dependencies

### Depends On
- FRD-001 (samples referenced), FRD-007 (audit), FRD-008 (roles, RLS, and the
  identity service that performs re-authentication).
- ADR-0003 (hash-chained audit in the domain transaction) — the same discipline,
  applied to the notebook.

### Depended On By
- FRD-010 (publishing) — `notebook.signed` is one of the three outbox triggers
  (FR-055); the signed PDF and hash travel to LabKey.
- FRD-004 (jobs) — a job step may produce a notebook entry.

---

## 9. Open Questions

1. **What exactly is canonicalised?** JCS (RFC 8785), or a project-defined
   canonical form? This determines whether a hash is verifiable by a third party
   and **needs an ADR** before implementation.
2. What is the maximum age of a "fresh" re-authentication? The specification says
   fresh; it does not say how fresh.
3. Should signing require multi-factor authentication? Flagged as questionable
   scope in the premium-feature harvest: no requirement specifies MFA for
   signatories, for a system whose signatures are meant to bind.
4. Is a counter-signature (two signers) ever required? Not specified.

---

## 10. Non-Functional Requirements

**CON-004** is the hard constraint: no update path may mutate a signed notebook.
**CON-014** gives the ELN an independent acceptance; CON-013 sets the I4 gate as
"ELN done at signature". Determinism (AGENTS.md §4) is load-bearing here in a way
it is nowhere else: a non-deterministic canonicalisation would make every
signature unverifiable.
