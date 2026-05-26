# RAG / Context-Pack Builder v0.1

**Status:** Design — not yet implemented
**Created:** 2026-05-26
**Depends on:** `RedactedFindingBrief/v1`, `SecurityFactGraph/v1`, `validate_outbound_cloud_payload()`, local redaction registry

## Purpose

Build a **cloud-safe ContextPack** from local redacted evidence so cloud LLMs can draft strategy and proof cards without seeing raw target data.

The builder must never receive or emit raw client identifiers, credentials, exact internal URLs, session data, unredacted screenshots, packet payloads, or executable target-specific commands. OWASP recommends least-privilege tool access, scoped permissions, explicit approval for sensitive operations, human-in-the-loop controls, audit trails, and structured output validation for AI agents.

---

## Taxonomy: Three Orthogonal Dimensions

The design uses three separate axes instead of conflating them into one enum. This follows NIST SP 800-115 (separate scope, authorization, and technique), PTES (scope defines *what*, ROE defines *how*), and OWASP agent guidance (separate classification, approval, and execution).

### Axis 1 — Action Risk (canonical enforcement enum)

This is the existing `validation_action_risk` enum, already defined in Python, TypeScript, and SQL. It is the single source of truth for all machine-enforced approval and quarantine logic. **Do not rename these values.**

| Value | Rung | Auto-run? | Examples |
|-------|------|-----------|----------|
| `passive` | 0 | Yes | Log review, config review, evidence comparison, report analysis |
| `active_read_only` | 1 | Yes, if scoped | Metadata reads, version checks, permission inspection, HEAD/GET probes |
| `active_non_destructive_differential` | 2 | Yes, if scoped | Boolean-based checks, timing probes, differential comparison, SQLi probe without extraction |
| `controlled_canary` | 3 | Approval required unless pre-authorized | OAST/out-of-band callback, blind SSRF to owned collaborator, blind XSS callback |
| `reversible_state_change` | 4 | Approval required | Create/update/delete test resources, account modifications, config changes |
| `destructive_or_data_access` | 5 | Approval required | Exploit validation, privilege escalation, payload execution, data extraction, brute force |

`controlled_canary` is a distinct rung because it causes the target to communicate externally. PortSwigger documents OAST as a separate validation pattern for blind vulnerabilities (blind SSRF, blind SQLi, blind XSS, blind OS command injection) using an operator-controlled collaborator endpoint. OWASP agent guidance treats externally visible operations as higher-impact actions requiring stronger controls. Default to operator approval unless the engagement explicitly pre-authorizes owned callback domains or a private collaborator endpoint.

### Axis 2 — Scope Status (authorization boundary)

Separate from action risk. A step can be low-risk but out of scope, or high-risk but in scope.

```
scope_status: "in_scope" | "scope_unknown" | "out_of_scope"
```

Any `out_of_scope` step is hard-blocked before rehydration or execution, regardless of its action risk. `scope_unknown` defaults to quarantined unless the operator confirms scope.

### Axis 3 — Policy Disposition (approval state)

```
policy_disposition: "auto_allowed" | "requires_operator_approval" | "blocked"
```

Computed from action risk × scope status × engagement policy. Separate from the risk classification itself — the same `active_read_only` step may be `auto_allowed` in one engagement and `requires_operator_approval` in another.

### Optional: Proof Step Kind (non-authoritative descriptive label)

If the strategist model benefits from a richer descriptive taxonomy, add an optional `proof_step_kind` field. This is **never used for enforcement** — local policy keys off `validation_action_risk`, `scope_status`, and `policy_disposition` only.

```
proof_step_kind: "evidence_review" | "metadata_read" | "differential_probe"
               | "oast_canary" | "reversible_write" | "exploit_attempt"
```

---

## 1. Inputs

```ts
type BuildContextPackRequest = {
  request_id: string;
  finding_brief: RedactedFindingBriefV1;
  fact_graph: SecurityFactGraphV1;
  scope_policy_ref: string;
  engagement_policy_ref: string;
  finding_type_hint?: string;       // e.g. "idor", "ssrf", "sqli", "authz_bypass"
  desired_output: "proof_card" | "strategy" | "triage" | "counterevidence_review";
  max_context_tokens: number;
  max_chunks: number;
  retrieval_profile: "fast" | "balanced" | "high_recall";
  cloud_policy: CloudDisclosurePolicyV1;
};
```

Required preconditions:

```ts
assert(finding_brief.schema_version === "RedactedFindingBrief/v1");
assert(fact_graph.schema_version === "SecurityFactGraph/v1");
assert(validate_outbound_cloud_payload(request) === "allow");
```

---

## 2. Retrieval Corpus

Use three corpus tiers with a policy-governed security boundary between them. NIST SP 800-115 treats assessment planning, legal/policy constraints, execution, and data handling as core parts of security testing — corpus selection is a policy decision, not a search convenience.

### Tier A — Public Authoritative Corpus

- OWASP WSTG / ASVS / Cheat Sheets
- CWE
- CAPEC
- NVD / CVE records
- CISA KEV
- FIRST EPSS
- Vendor advisories
- Vendor product documentation
- Internal methodology notes that contain no client data

### Tier B — Internal Cloud-Safe Corpus

Only redacted and approved material:

- Prior redacted proof cards with operator outcomes
- Safe proof patterns
- Stop-condition policies
- Sanitized validation ladders
- Generic methodology snippets
- Redacted postmortems

### Tier C — Local-Only Corpus

Never sent to cloud, never indexed into a retrievable cloud corpus:

- Raw evidence
- Real hostnames / IPs / URLs
- Screenshots with sensitive content
- Credentials, tokens, cookies
- Packet captures
- Client source code
- Exact asset mappings

---

## 3. Chunking Strategy

Metadata-aware chunks, not blind fixed-size windows.

```ts
type RetrievalChunk = {
  chunk_id: string;
  source_id: string;
  source_type:
    | "owasp"
    | "cwe"
    | "cve"
    | "vendor_advisory"
    | "vendor_doc"
    | "methodology"
    | "prior_redacted_card"
    | "policy";
  title: string;
  section_path: string[];
  text: string;
  normalized_tags: string[];
  cwe_ids?: string[];
  cve_ids?: string[];
  affected_products?: string[];
  validation_risk_tags?: string[];  // from validation_action_risk values
  created_at?: string;
  updated_at?: string;
  trust_level: "authoritative" | "vendor" | "internal_approved" | "low";
};
```

Initial chunking defaults:

```yaml
chunk_size_tokens: 350-800
chunk_overlap_tokens: 50-120
preserve:
  - headings
  - tables as normalized markdown
  - code blocks only from public/vendor docs
  - source URL / document ID
  - section hierarchy
split_on:
  - heading
  - paragraph
  - list item group
  - table boundary
```

Anthropic reports that embeddings + BM25, contextual chunking, reranking, and passing top-20 chunks performed better than smaller top-k sets in contextual retrieval experiments.

---

## 4. Retrieval and Reranking Pipeline

```text
RedactedFindingBrief
        │
        ▼
QueryPlanner
        │
        ├─ lexical query: CWE/CVE/product/security terms
        ├─ semantic query: vulnerability hypothesis + evidence summary
        └─ policy query: proof ladder + stop conditions
        │
        ▼
HybridRetriever
        ├─ BM25 top N
        └─ embedding top N
        │
        ▼
CandidateMerge
        │
        ▼
LocalReranker
        │
        ▼
ContextPackAssembler
        │
        ▼
OutboundCloudPayloadGate
```

Recommended defaults:

```yaml
fast:
  bm25_k: 40
  embedding_k: 40
  rerank_k: 50
  final_k: 8-12

balanced:
  bm25_k: 80
  embedding_k: 80
  rerank_k: 100
  final_k: 12-16

high_recall:
  bm25_k: 150
  embedding_k: 150
  rerank_k: 150
  final_k: 16-20
```

All embedding and reranking for client-derived queries runs locally unless the outbound gate explicitly approves the payload. Future RAG/embedding calls must reuse `validate_outbound_cloud_payload()`.

---

## 5. ContextPack Output Contract

```ts
type ContextPackV1 = {
  schema_version: "ContextPack/v1";
  pack_id: string;
  request_id: string;

  disclosure_class: "cloud_safe_redacted";
  source_brief_id: string;
  source_fact_graph_id: string;

  task: {
    desired_output: "proof_card" | "strategy" | "triage" | "counterevidence_review";
    finding_type_hint?: string;
    allowed_reasoning_boundary: string[];
    forbidden_outputs: string[];
  };

  redacted_case_summary: {
    asset_roles: string[];
    service_families: string[];
    auth_context?: string;
    observed_failure_modes: string[];
    evidence_refs: string[];
    uncertainty_notes: string[];
  };

  retrieved_context: Array<{
    chunk_id: string;
    source_id: string;
    source_type: string;
    title: string;
    section_path: string[];
    text: string;
    relevance_score: number;
    reason_selected: string;
  }>;

  proof_policy: {
    allowed_validation_action_risks: string[];   // values from validation_action_risk enum
    blocked_validation_action_risks: string[];
    stop_conditions: string[];
    human_approval_required_for: string[];
  };

  grounding_requirements: {
    must_cite_evidence_refs: boolean;
    must_include_counterevidence: boolean;
    must_abstain_if_unsupported: boolean;
    min_supporting_chunks: number;
  };

  budgets: {
    max_context_tokens: number;
    estimated_context_tokens: number;
    max_output_tokens: number;
  };

  audit: {
    builder_version: string;
    retrieval_profile: string;
    corpus_versions: Record<string, string>;
    outbound_gate_decision_id: string;
    created_at: string;
  };
};
```

---

## 6. Prompt Format for Strategist Model

Use strict structured output. OpenAI's structured outputs support JSON Schema with `strict: true`, and the response can be parsed into matching typed objects after validation.

Prompt layout:

```text
SYSTEM:
You are a cloud-side security reasoning assistant.
You only reason over redacted evidence.
You must not infer raw target identifiers.
You must not produce executable target-specific commands.
You must produce only the requested JSON schema.

CONTEXT PACK:
<ContextPack/v1 JSON>

TASK:
Draft a parameterized proof card.

REQUIREMENTS:
- Cite evidence_refs and retrieved chunk IDs.
- Separate claim, support, counterevidence, missing evidence, and validation plan.
- Prefer passive/active_read_only validation.
- Classify each step's action risk using ONLY these values:
  passive | active_read_only | active_non_destructive_differential
  | controlled_canary | reversible_state_change | destructive_or_data_access
- Mark every step with approval_required based on the table below.
- Abstain if evidence is insufficient.

OUTPUT:
<ProofCard/v1 JSON schema only>
```

---

## 7. ProofCard Output Contract

```ts
type ProofCardV1 = {
  schema_version: "ProofCard/v1";
  card_id: string;
  finding_hypothesis: string;

  claim: {
    summary: string;
    affected_asset_placeholders: string[];
    weakness_class?: {
      cwe_id?: string;
      owasp_category?: string;
    };
    confidence: "low" | "medium" | "high";
  };

  evidence: {
    supporting_evidence_refs: string[];
    supporting_chunk_ids: string[];
    counterevidence_refs: string[];
    missing_evidence: string[];
  };

  validation_plan: Array<{
    step_id: string;
    validation_action_risk:
      | "passive"
      | "active_read_only"
      | "active_non_destructive_differential"
      | "controlled_canary"
      | "reversible_state_change"
      | "destructive_or_data_access";
    proof_step_kind?:             // non-authoritative, never used for enforcement
      | "evidence_review"
      | "metadata_read"
      | "differential_probe"
      | "oast_canary"
      | "reversible_write"
      | "exploit_attempt";
    scope_status: "in_scope" | "scope_unknown" | "out_of_scope";
    policy_disposition: "auto_allowed" | "requires_operator_approval" | "blocked";
    parameterized_action: string;
    required_placeholders: string[];
    expected_observation: string;
    safety_notes: string[];
    approval_required: boolean;
  }>;

  stop_conditions: string[];
  abstention_reason?: string;
};
```

---

## 8. Validation Safety Rules

Enforcement uses three axes: action risk × scope status → policy disposition.

| Action Risk | In Scope | Scope Unknown | Out of Scope |
|-------------|----------|---------------|--------------|
| `passive` | `auto_allowed` | `requires_operator_approval` | `blocked` |
| `active_read_only` | `auto_allowed` | `requires_operator_approval` | `blocked` |
| `active_non_destructive_differential` | `auto_allowed` | `requires_operator_approval` | `blocked` |
| `controlled_canary` | `requires_operator_approval`¹ | `requires_operator_approval` | `blocked` |
| `reversible_state_change` | `requires_operator_approval` | `requires_operator_approval` | `blocked` |
| `destructive_or_data_access` | `requires_operator_approval` | `requires_operator_approval` | `blocked` |

¹ `controlled_canary` may be pre-authorized to `auto_allowed` if the engagement explicitly lists owned callback domains or a private collaborator endpoint.

Default rule:

```text
Only passive and active_read_only steps may be auto-runnable.
Everything else requires explicit operator approval.
controlled_canary requires pre-authorized collaborator endpoints.
out_of_scope steps are blocked, not queued — regardless of action risk.
```

NIST SP 800-115 distinguishes examination/review activities from testing activities and emphasizes tailoring techniques to assessment objectives, risk tolerance, planning, safeguards, and rules of engagement. PTES separates scope (what is tested) from ROE (how testing is allowed).

---

## 9. UQLM / Hallucination Defense

Run proof cards through a local verifier before rehydration:

```text
ProofCard
  → schema validation
  → citation/grounding check
  → contradiction check
  → uncertainty scoring
  → policy/scope check
  → human review queue if risky
```

Use UQLM-style uncertainty as one signal, not as a sole approval mechanism. Recent UQLM work describes black-box, white-box, judge-based, and ensemble uncertainty scoring for hallucination detection, with ensemble scoring intended to improve reliability over individual scorers.

Minimum verifier output:

```ts
type ProofCardVerificationV1 = {
  card_id: string;
  schema_valid: boolean;
  grounding_score: number;
  uncertainty_score: number;
  contradiction_score: number;
  unsupported_claims: string[];
  risky_steps: string[];
  policy_blocks: string[];
  decision: "allow_passive_only" | "queue_human_review" | "reject";
};
```

---

## 10. Rehydration Boundary

Cloud output must remain parameterized.

Allowed:

```text
READ_METADATA(asset_placeholder=HOST_A17, service=HTTP_SERVICE_2)
```

Forbidden:

```text
curl https://real-client-host.internal/admin/delete?id=...
```

Local rehydration flow:

```text
ProofCard/v1
  → local schema validation
  → local UQLM/grounding verification
  → placeholder binder
  → scope engine
  → action-risk classifier (uses canonical validation_action_risk)
  → operator approval if required
  → local executor
  → evidence store
```

Cloud models must never approve, execute, or bind real targets.

---

## 11. Existing Scaffolding (already built)

| Component | Location |
|-----------|----------|
| `RedactedFindingBrief/v1` dataclass | `hermes-agent/scripts/offensive-research-portal-task-runner.py:1266` |
| `SecurityFactGraph/v1` builder | Same file, `build_security_fact_graph()` |
| `validate_outbound_cloud_payload()` | Same file, line 1085 — schema allowlist, leak detection, size budget |
| `classify_validation_action_risk()` | Same file — maps steps to canonical risk enum |
| `requires_quarantine()` | Same file — shadow-mode, scope, and risk-based quarantine |
| `build_validation_card()` | Same file — produces validation card dict (precursor to ProofCardV1) |
| `LocalRedactionRegistry` | Same file — redact/rehydrate with stable reference IDs |
| `vuln_intel_adapter.py` | `hermes-agent/scripts/vuln_intel_adapter.py` — NVD, KEV, EPSS, OSV queries |
| `uqlm_verify.py` | `hermes-agent/scripts/uqlm_verify.py` — UQLM verification |
| Canonical enum (Python) | `VALIDATION_ACTION_RISK_VALUES` in task_runner.py |
| Canonical enum (TypeScript) | `VALID_VALIDATION_ACTION_RISK` in `report-viewer/lib/proof-policy.ts` |
| Canonical enum (SQL) | Check constraint in `supabase/migration-release-e-missing.sql` |
| Enum consistency tests | `hermes-agent/tests/test_enum_consistency.py` — verifies Python/TS/SQL alignment |

---

## 12. Acceptance Criteria

The RAG/context-pack builder is ready for implementation only when these are defined:

```yaml
must_have:
  - ContextPack/v1 schema
  - ProofCard/v1 schema (aligned to canonical validation_action_risk enum)
  - BuildContextPackRequest schema
  - Retrieval corpus manifest format
  - Chunk metadata schema
  - Outbound cloud payload policy
  - Test fixtures with redacted findings
  - Golden expected context packs
  - Hallucination/grounding evaluation harness
  - Cost and token budget config
  - Audit log format

must_not_have:
  - Raw target identifiers in ContextPack
  - Executable real-target commands in ProofCard
  - Cloud-side target binding
  - Cloud-side approval decisions
  - Bypass path around validate_outbound_cloud_payload
  - Second validation_action_risk-like enum
  - out_of_scope as a validation_action_risk value
```

## Design Decisions (resolved)

1. **Keep existing `validation_action_risk` enum.** It is the single canonical enforcement enum in Python, TypeScript, and SQL. Renaming it is a backward-incompatible change — PostgreSQL enum values cannot be removed or reordered without dropping and recreating the type. The spec aligns to the code, not the other way around.

2. **`controlled_canary` is a first-class rung.** OAST is a distinct validation pattern (PortSwigger, OWASP agent guidance). It stays separate from `active_non_destructive_differential` because it causes external communication and requires pre-authorized collaborator endpoints.

3. **`out_of_scope` is NOT a risk value.** It is a scope/policy axis. NIST SP 800-115 and PTES separate scope boundaries from test techniques. A step can be low-risk but out of scope, or high-risk but in scope. Model it as `scope_status` + `policy_disposition`, not as a risk enum value.

4. **Three orthogonal axes for enforcement:** `validation_action_risk` (what risk does this action carry?), `scope_status` (is this target authorized?), `policy_disposition` (computed: auto-allowed, approval-gated, or blocked?). `proof_step_kind` is an optional non-authoritative descriptive label, never used for enforcement.
