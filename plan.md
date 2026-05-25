# Pentest Workbench — Product Architecture

A pentest workbench where **one command bootstraps the full stack** with guided onboarding. **The operator is the decision maker. AI is the research assistant.**

**Last audited:** 2026-05-24 against `cc-switch`, `offensive-research-portal`, `hermes-agent`, root docs, and the current feature branches for local-first model routing, UQLM verification, and the sensitive-evidence boundary described below.

---

## The Team

### cc-switch — Central Management Platform

Your command center. Everything goes through cc-switch. Runs local (Tauri/Rust), no internet required for operation.

- Workflow management — create, edit, approve execution plans before anything runs
- Skill management — browse, add, configure pentest skills, enable/disable
- Model routing — selects the best allowed model per task from your pool based on policy, measured capability records, sensitivity, and runtime health; delegates on failure, alerts on limits, circuit-breaks unhealthy providers

### Hermes — Offensive Team

AI agents that execute pentesting. Uses the full methodology from `pentest-ai-agents` (35 specialist subagents across five domains):

| Domain | Agents | Role |
|--------|--------|------|
| Recon | recon-advisor, osint-collector, threat-modeler | Map attack surface, enumerate targets |
| Web | web-hunter, api-security, bizlogic-hunter | XSS, SQLi, auth bypass, hidden endpoints |
| Exploitation | exploit-chainer, payload-crafter, poc-validator, credential-tester | Build and validate exploit chains |
| Specialized | cloud-security, container-breakout, mobile-pentester, wireless-pentester, cicd-redteam | Domain-specific attacks |
| Command | attack-planner, engagement-planner, swarm-orchestrator, _scope-guard | Plan, coordinate, enforce scope |

**Methodology gap:** pentest-ai-agents agents use MITRE ATT&CK (34/35) and CVE/NVD (13/35) but lack operational vuln management: CISA KEV (0), EPSS (0), CPE (0), SSVC (0). The `enrich_vuln_intel` Fabric pattern fills this — it runs the 6-stage pipeline (CVE → KEV+EPSS → asset match → CWE → SSVC → vendor fix) before Fabric enrichment touches the finding.

Execution-constrained by operator authority policy. Proposes attacks, waits for approval, executes approved actions only. Never exploits autonomously. Never acts out of scope.

### Fabric — Report Writer & Enrichment Engine

Handles all documentation. AI pattern library that runs locally. Patterns at `~/.config/fabric/patterns/`.

- `enrich_vuln_intel` — enriches findings with real threat intelligence: CVE/NVD lookup, CISA KEV check, EPSS score, asset match, CWE + OWASP mapping, SSVC action decision (Track/Track*/Attend/Act), vendor fix recommendation
- `enrich_finding` — fills 6 missing fields from raw findings with per-field confidence scores
- `csp_evaluation` — practical CSP fix plans from scan data
- `pentest_finding_draft` — raw scan output → structured finding drafts
- `pentest_report` — confirmed findings → professional PTES/OWASP report

### UQLM — Hallucination Detector

CVS Health's uncertainty quantification library (Apache 2.0, cloned at `uqlm/`). Python/LangChain-based, runs inside the Hermes container. Provides independent verification of Fabric's enrichment output — the model that generates the content is not the model that judges it.

**Scorer types and field mapping:**

| Scorer | Method | Applied to | What it catches |
|--------|--------|------------|-----------------|
| `semantic_negentropy` | NLI clustering of 5 generations | `vuln_type`, `cwe_id`, `cvss_vector` | Model guessing between SQLi and XSS across runs |
| `noncontradiction` | Bidirectional NLI contradiction check | `impact`, `remediation` | Impact claims that contradict each other |
| `cosine_sim` | Sentence-transformer embeddings | Overall enrichment JSON | Semantic drift between generations |
| `exact_match` | String equality | `cwe_id`, `affected_url` | Fields that should be extracted, not invented |
| `LongTextUQ` (entailment) | Claim decomposition + NLI | `impact`, `remediation`, `reproduction_steps` | Individual claims not entailed by sampled responses |
| `LLMPanel` | 2+ judge models score output | Overall finding quality | Separate models flag implausible enrichment |

**Key insight:** `noncontradiction` + `LongTextUQ` is the strongest combination for our use case. Semantic entropy catches classification variance (Fabric says "SQLi" in one run and "XSS" in another). Non-contradiction catches when the impact paragraph describes effects inconsistent with the finding type. LongTextUQ with `response_refinement=True` auto-strips hallucinated claims from the output.

### Portal — Dashboard + API Boundary

Next.js app on Vercel. **Displays operator data and exposes server-side API routes. Never executes tasks. Never holds model or scanner credentials in browser/client code.**

- Views engagements, findings, reports, agent status from Supabase
- Operator triage: confirm/reject findings, review quarantine queue
- "Generate Report" button → creates task → Hermes + Fabric do the work
- Quality and sensitive-data gates at API write boundary (`lib/enrichment-gate.ts` plus the Release D boundary checks)
- All data flow: **Local executes → Portal API → Supabase → Portal reads**

### Claude Code + oh-my-claudecode

Your development assistant. 19 specialist agents for building and maintaining the workbench. Skills (`$ralph`, `$autopilot`, `$team`, `$ralplan`) for autonomous multi-agent workflows. Team pipeline: plan → prd → exec → verify → fix loop.

### You — Team Lead / Security Researcher

You manage the AI team through cc-switch. You approve high-risk actions. You validate findings manually. You make the calls.

---

## Architecture

```
                    ┌─────────────────┐
                    │    Operator     │
                    │  (you, in CLI)  │
                    └────────┬────────┘
                             │ manages via cc-switch
                             ▼
       ┌─────────────────────────────────────────────┐
       │                cc-switch                    │
       │  workflow manager · skill manager · router  │
       └────────┬──────────┬───────────┬────────────┘
                │          │           │
       ┌────────▼──┐ ┌─────▼──────┐ ┌─▼──────────┐
       │  Hermes   │ │  Fabric    │ │  Portal    │
       │ (offense) │ │ (reports)  │ │ (read-only)│
       │  Python   │ │  Go CLI    │ │  Vercel    │
       │  local    │ │  local     │ │            │
       └─────┬─────┘ └─────┬──────┘ └──────┬─────┘
             │             │               │
   ┌─────────▼──────┐      │               │
   │   UQLM         │      │               │
   │ (hallucination │      │               │
   │  detection)    │      │               │
   │  Python/LChain │      │               │
   └─────────┬──────┘      │               │
             │             │               │
             ▼             ▼               │
       ┌─────────────────────────────┐     │
       │  Portal API (Next.js routes) │     │
       │  auth → validate → gate →   │◄────┘
       │  write → audit              │  reads
       └────────────┬────────────────┘
                    │ service_role key
                    ▼
       ┌────────────────────────────────┐
       │    Supabase (PostgreSQL)       │
       │  engagements, findings, tasks  │
       │  RLS deny-all · service_role   │
       └────────────────────────────────┘
```

Local components operate without internet. Supabase adds persistence and the Portal adds visibility.

### Two Topologies

| | Local (docker compose) | Production |
|---|---|---|
| cc-switch | Local Tauri app | Same |
| Hermes + UQLM | Docker container | Docker on your server |
| Fabric | Docker / CLI | Same |
| Portal | localhost:3000 | Vercel |
| Database | Supabase cloud | Same |
| Models | Ollama / cloud API | Same |
| Purpose | Development + testing | Live engagements |

### Sensitive Evidence Boundary

This is the privacy and model-routing contract for the whole workbench. It exists because local models are useful but may not be smart enough for every high-impact finding, while cloud models must not receive raw target data, secrets, PII, or customer-specific evidence.

**Invariant:** raw sensitive evidence stays local unless the operator explicitly approves disclosure for a specific action. Cloud models and the cloud Portal receive only redacted, structured briefs.

| Data class | Examples | Allowed destinations | Rule |
|---|---|---|---|
| `raw_local_only` | Real IPs, private domains, internal URLs, credentials, screenshots with sensitive text, customer names, request/response bodies containing secrets | Local SQLite, Hermes local process, local model, local UQLM, cc-switch local UI | Never send to cloud model or cloud database by default |
| `redacted_cloud_ok` | `[DOMAIN_REF_1]`, `[IP_REF_1]`, normalized service metadata, CWE/CVE/EPSS/KEV, sanitized request shape, redacted reproduction context | Cloud model, Portal API, Supabase | Safe for cloud reasoning and dashboard storage |
| `public` | Public CVE data, vendor advisory text, CISA KEV, EPSS, OWASP/CWE references | Any configured model or service | No local-only restriction |

#### Local redaction registry

Hermes creates stable reference IDs before any cloud boundary:

```text
Raw finding
  -> LocalRedactionRegistry
  -> RedactedFindingBrief
  -> cloud-safe model prompt / Portal payload
```

The registry is local-only and stored with operator-controlled permissions. It maps references back to real values for review:

```json
{
  "engagement_id": "eng_123",
  "refs": {
    "[DOMAIN_REF_1]": "admin.internal.example",
    "[IP_REF_1]": "10.10.20.15",
    "[SECRET_REF_1]": "redacted-real-secret"
  }
}
```

The registry is not uploaded to Portal or Supabase. Portal stores the redacted finding. cc-switch or a local CLI rehydrates the finding for the operator during manual review and testing.

#### Cloud model role

Cloud models may be used for reasoning quality, but only against a redacted brief. They produce:

- likely vulnerability class and reasoning
- test strategy
- low-noise reproduction template
- evidence checklist
- questions for the local model or operator

Cloud models must not produce final raw commands containing real targets because they do not know the real target values. They can produce parameterized instructions using references:

```text
Check whether [DOMAIN_REF_1] exposes an unauthenticated admin route.
Have the local executor resolve [DOMAIN_REF_1] and perform a safe HEAD/GET probe only.
```

#### Local model and local executor role

The local model, Hermes, and cc-switch may rehydrate references because they run on the operator-controlled machine. Their job is to convert the cloud-safe strategy into local, scope-checked, operator-reviewable actions:

```text
Cloud model: "test [DOMAIN_REF_1] for missing auth on /admin"
Local rehydration: "[DOMAIN_REF_1] -> admin.internal.example"
Scope guard: confirm admin.internal.example is in engagement scope
Action gate: if high/critical or destructive, ask operator
Hermes: execute only approved safe probe
```

This keeps cloud reasoning useful without leaking raw evidence.

#### Model routing sensitivity invariant

Every model-routing request must include a sensitivity classification:

| `data_sensitivity` | Router behavior |
|---|---|
| `raw_local_only` | cc-switch may select only local providers. If no capable local provider exists, route to operator review or request redaction first. |
| `redacted_cloud_ok` | cc-switch prefers capable local providers, then may fall back to cloud providers based on skill, tags, quality floor, and circuit state. |
| `public` | cc-switch may choose any capable provider based on strategy and cost/quality policy. |

Local-first means "local if capable and allowed." It does not mean "use a weak local model for tasks it cannot reason about." If local capability is insufficient, Hermes must build a `RedactedFindingBrief` before asking a cloud model.

#### Portal storage invariant

Portal and Supabase are the cloud operating record. They must store:

- redacted target references, not raw sensitive values
- UQLM/Fabric confidence metadata
- model-routing audit records
- operator approval and triage decisions

They must not store raw secrets, private target identifiers, or unredacted exploit material unless the operator explicitly marks a specific value as shareable for that engagement.

#### UQLM interaction

UQLM does not block this model. It supports it.

- For local-only work, UQLM may verify raw evidence and raw reproduction steps locally.
- For cloud-assisted work, UQLM verifies whether the cloud output is consistent with the redacted brief and does not invent non-existent facts.
- UQLM is advisory to the gate. Low score means reject, refine, or route to operator review. It is not an autonomous truth oracle and does not override operator authority.

Required tests for this boundary:

- Portal API rejects or quarantines obvious raw secrets/private IPs in cloud-bound finding fields.
- Hermes builds stable references for sensitive values before cloud model calls.
- cc-switch refuses cloud routing when `data_sensitivity = raw_local_only`.
- Local review can rehydrate references for the operator without writing raw values back to Portal.
- UQLM can score redacted reproduction templates without requiring raw target values.

### Post-Enumeration Proof Assistant

Hermes is not treated as a self-authorizing exploit agent. After enumeration, its primary job is to reduce the operator's search and proof burden by turning observed evidence into low-noise validation cards.

**Invariant:** high impact does not automatically mean high-risk validation. The system must classify the proposed validation action separately from the suspected vulnerability severity.

#### Validation card

Every post-enumeration hypothesis should be represented as a validation card before action:

| Field | Purpose |
|---|---|
| `hypothesis` | What Hermes thinks may be vulnerable, phrased as a falsifiable claim. |
| `observed_evidence` | What was actually seen during enumeration, using redacted refs where needed. |
| `standards_mapping` | CWE, OWASP WSTG/ASVS, CVE/KEV/EPSS, vendor advisory if relevant. |
| `vulnerability_severity` | Potential business/security impact if the hypothesis is true. |
| `validation_action_risk` | Risk of the proposed proof step itself. This controls approval. |
| `lowest_risk_proof` | The least intrusive test that can confirm or falsify the hypothesis. |
| `expected_positive` | What result would support the hypothesis. |
| `expected_negative` | What result would falsify or weaken the hypothesis. |
| `stop_conditions` | Conditions that require stopping before deeper testing. |
| `data_sensitivity` | `raw_local_only`, `redacted_cloud_ok`, or `public`. |
| `model_trace` | Model/profile used, prompt version, UQLM score, and router decision ID. |
| `operator_decision` | Approve, reject, needs-more-context, or manually validated. |

This gives the operator quick proof material without pretending the model is the final authority.

#### Proof ladder

Hermes must prefer the lowest-risk proof that can answer the question. It may not jump to a higher rung merely because the finding would be high impact if true.

| Rung | Validation type | Examples | Runtime rule |
|---|---|---|---|
| 0 | Passive corroboration | Version/header review, source/advisory match, existing logs, screenshots already collected | Always allowed in scope |
| 1 | Read-only safe probe | `GET`, `HEAD`, `OPTIONS`, metadata fetch, unauthenticated baseline request | Allowed in approved workflow with rate limits |
| 2 | Non-destructive differential test | Authorized vs unauthenticated compare, invalid token compare, benign boolean signal, strict timeout | Allowed if scoped and pre-approved; notify on high/critical hypothesis |
| 3 | Controlled canary/OOB proof | Request to operator-owned callback, harmless marker, no internal pivot or scan | Requires preconfigured owned callback and audit record |
| 4 | Reversible state-changing proof | Create test-only object, modify disposable test account, restore immediately | Requires explicit operator approval |
| 5 | Destructive, DoS, data access, persistence, or exploit chain | Dump data, delete/modify real data, high-load timing, service crash, privilege escalation chain | Explicit approval or lab-only reproduction |

Rules:

- If a lower rung gives enough proof, stop.
- If a lower rung fails, record why before proposing a higher rung.
- DoS findings should normally be validated through passive evidence, configuration review, lab reproduction, or strict non-impact limits, not production disruption.
- Data extraction is not a proof method by default. Use metadata, counts, canaries, or operator-provided test records where possible.
- Auth bypass validation should stop as soon as unauthorized access is demonstrated; do not browse deeper without approval.

### Model Capability Governance

Public benchmarks, vendor claims, and model tags are only priors. They can suggest candidate models, but they do not prove that a model is useful for this workbench.

**Invariant:** model routing is trusted only inside skills where the model has measured local evidence.

#### Capability records

cc-switch should maintain capability records per model/profile/skill:

| Field | Meaning |
|---|---|
| `model_identifier` | Provider model ID. |
| `profile` | Local executor, cloud strategist, UQLM judge, report writer, rapid validator, etc. |
| `skill_tag` | Skill this model was evaluated for. |
| `data_sensitivity_allowed` | Maximum allowed sensitivity for this profile. |
| `proof_quality_score` | Human/UQLM score for validation-card usefulness. |
| `grounding_score` | Whether output stayed tied to observed evidence and refs. |
| `safety_score` | Whether it selected low-risk proof steps and respected stop conditions. |
| `latency_ms_p50/p95` | Runtime usefulness for time-sensitive work. |
| `cost_estimate` | Token/cost profile. |
| `failure_rate` | Refusals, tool errors, malformed output, or hallucinated target facts. |
| `promotion_state` | `candidate`, `shadow`, `approved`, `restricted`, or `disabled`. |

#### Promotion rules

- New models start as `candidate` or `shadow`, never as trusted runtime defaults.
- A shadow model may produce validation cards for comparison, but Hermes must not execute actions from it.
- Promotion requires reviewed local golden tasks for the relevant skill, not just public leaderboard scores.
- A model can be approved for `report_draft` but restricted for `exploit_validation`; capability is skill-specific.
- UQLM disagreement, operator rejection, or repeated noisy proof cards should lower the model's capability record.
- The router chooses the best allowed model from capability records; it does not infer trust from a model name.

#### Human intervention points

Human review is best used where it changes stability:

| Point | Why human review is needed |
|---|---|
| Model promotion | Confirms the model is useful for a specific skill in this workspace. |
| Ambiguous scope | Prevents accidental out-of-scope testing. |
| Proof ladder escalation | Ensures the next validation step is worth the risk. |
| UQLM/model disagreement | Prevents confident hallucinations from becoming action. |
| High-impact + weak evidence | Lets the operator decide whether to gather more proof or stop. |
| State-changing/destructive/data-access proof | Preserves operator authority and engagement rules. |

This is the safe interpretation of a self-improving Hermes: it improves from operator-reviewed outcomes and measured capability records. It must not rewrite policy, promote models, or authorize higher-risk actions by itself.

### Storage and Portal View Contract

The proof-driven flow needs real schema, API, and UI contracts. Otherwise `validation_action_risk`, proof cards, and model capability records will become loose JSON fields that different services interpret differently.

#### Current storage truth

| Store | Current role | Current implementation | Rule |
|---|---|---|---|
| Hermes local operational DB | Durable local queue, checkpoints, raw/local-only working state | SQLite at `PENTEST_DB_PATH` in the `hermes-home` Docker volume | May hold raw local evidence and redaction registry refs. Not directly exposed to Portal. |
| cc-switch local DB | Model/provider config, routing health, capability records, operator settings | cc-switch local SQLite | Owns model trust and routing policy. Syncs only audit-safe summaries. |
| Portal/Supabase | Cloud operating record and dashboard state | Supabase Postgres through Portal API | Stores redacted findings, proof cards, audit records, model route logs. No raw local-only evidence by default. |
| Local PostgreSQL / local Supabase dev | Optional future local mirror for full-stack dev | Not currently defined in `docker-compose.yml` | If added, it must use the same Supabase schema/migrations and parameter names. Do not create a second dialect of the workflow model. |

The current root `docker-compose.yml` does **not** define a local PostgreSQL service. It points Portal at `SUPABASE_URL` and stores Hermes local state in SQLite. If we add local PostgreSQL or a Supabase local stack, the plan must be updated together with compose/env/schema so the local and cloud schemas remain identical.

#### Canonical enums and parameters

These names are canonical across Hermes, cc-switch, Supabase, Portal APIs, and Portal views:

| Parameter | Allowed values | Owner | Notes |
|---|---|---|---|
| `data_sensitivity` | `raw_local_only`, `redacted_cloud_ok`, `public` | Hermes classifies, cc-switch enforces | Controls whether cloud models/storage are allowed. |
| `vulnerability_severity` | `low`, `medium`, `high`, `critical` | Finding/enrichment pipeline | Impact if the hypothesis is true. Does not by itself decide execution. |
| `validation_action_risk` | `passive`, `active_read_only`, `active_non_destructive_differential`, `controlled_canary`, `reversible_state_change`, `destructive_or_data_access` | Hermes proof-card builder, approval policy | Risk of the proposed validation step. This controls approval/quarantine. |
| `proof_ladder_rung` | `0`, `1`, `2`, `3`, `4`, `5` | Hermes proof-card builder | Numeric ordering for lowest-risk proof selection. |
| `operator_decision` | `pending`, `approved`, `rejected`, `needs_more_context`, `manually_validated`, `false_positive` | Operator through cc-switch/Portal | Feeds model capability records. |
| `promotion_state` | `candidate`, `shadow`, `approved`, `restricted`, `disabled` | cc-switch | Controls model routing eligibility. |
| `skill_tag` | Existing workflow skill vocabulary | cc-switch/Hermes | Primary routing and capability key. Avoid new `task_type` logic. |

Legacy compatibility:

- Existing `action_class` values map to the new `validation_action_risk` values: `passive -> passive`, `active_non_destructive -> active_read_only` or `active_non_destructive_differential`, `active_destructive -> destructive_or_data_access`.
- Existing `risk_level` remains useful as a coarse workflow risk, but proof gating must use `validation_action_risk` plus `vulnerability_severity`.
- Existing `task_type` remains a compatibility alias for `skill_tag`; do not add new routing policy around `task_type`.

#### Supabase schema additions

`offensive-research-portal/supabase/schema.sql` remains canonical. Release E needs safe migrations for these records:

```sql
create table if not exists public.validation_cards (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  task_id uuid references public.agent_tasks(id) on delete set null,
  finding_id uuid references public.findings(id) on delete set null,
  hypothesis text not null,
  observed_evidence jsonb not null default '[]'::jsonb,
  standards_mapping jsonb not null default '{}'::jsonb,
  vulnerability_severity text not null check (vulnerability_severity in ('low', 'medium', 'high', 'critical')),
  validation_action_risk text not null check (validation_action_risk in (
    'passive',
    'active_read_only',
    'active_non_destructive_differential',
    'controlled_canary',
    'reversible_state_change',
    'destructive_or_data_access'
  )),
  proof_ladder_rung integer not null check (proof_ladder_rung between 0 and 5),
  lowest_risk_proof jsonb not null default '{}'::jsonb,
  expected_positive text,
  expected_negative text,
  stop_conditions jsonb not null default '[]'::jsonb,
  data_sensitivity text not null check (data_sensitivity in ('raw_local_only', 'redacted_cloud_ok', 'public')),
  model_trace jsonb,
  uqlm_score numeric(5,4),
  status text not null default 'pending' check (status in (
    'pending', 'approved', 'rejected', 'needs_more_context', 'manually_validated', 'false_positive'
  )),
  operator_decision text,
  operator_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

```sql
create table if not exists public.validation_attempts (
  id uuid primary key default gen_random_uuid(),
  validation_card_id uuid not null references public.validation_cards(id) on delete cascade,
  task_id uuid references public.agent_tasks(id) on delete set null,
  attempted_by text not null,
  action_summary text not null,
  validation_action_risk text not null,
  result text not null check (result in ('not_run', 'positive', 'negative', 'inconclusive', 'stopped', 'error')),
  evidence jsonb not null default '{}'::jsonb,
  stopped_reason text,
  created_at timestamptz not null default now()
);
```

```sql
create table if not exists public.model_capability_records (
  id uuid primary key default gen_random_uuid(),
  model_identifier text not null,
  profile text not null,
  skill_tag text not null,
  data_sensitivity_allowed text not null check (data_sensitivity_allowed in ('raw_local_only', 'redacted_cloud_ok', 'public')),
  proof_quality_score numeric(5,4),
  grounding_score numeric(5,4),
  safety_score numeric(5,4),
  latency_ms_p50 integer,
  latency_ms_p95 integer,
  cost_estimate numeric(12,6),
  failure_rate numeric(5,4),
  promotion_state text not null default 'candidate' check (promotion_state in ('candidate', 'shadow', 'approved', 'restricted', 'disabled')),
  evaluation_count integer not null default 0,
  last_evaluated_at timestamptz,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (model_identifier, profile, skill_tag, data_sensitivity_allowed)
);
```

Existing table changes needed:

- `agent_tasks`: add `data_sensitivity`, `validation_action_risk`, `proof_ladder_rung`, and `validation_card_id`.
- `workflow_steps`: replace or augment coarse `action_class` with `validation_action_risk` and `proof_ladder_rung`.
- `approval_policies`: move from `action_class + min_severity` to `validation_action_risk + min_vulnerability_severity`, keeping old rows as compatibility seed data.
- `findings`: keep raw proof-card details in `validation_cards`; store only summary refs in `metadata.validation_card_id` and redacted fields in finding columns.
- `audit_log`: include `validation_card_id`, `validation_action_risk`, `proof_ladder_rung`, and `data_sensitivity` in metadata for route/approval decisions.

#### Local DB requirements

Hermes local DB must be able to persist the same proof-card shape before sync:

- `validation_cards_local`: same logical fields as Supabase `validation_cards`, plus local-only raw evidence refs.
- `validation_attempts_local`: same logical fields as Supabase `validation_attempts`, plus raw request/response artifacts when allowed by local policy.
- `redaction_registry`: local-only ref mapping. Never sync this table to Supabase.
- `sync_queue`: enqueue redacted `validation_cards` and `validation_attempts` payloads for Portal API sync.

If local PostgreSQL replaces SQLite later, these tables move from SQLite to local Postgres without changing the API payloads or Supabase column names.

#### Portal API requirements

Portal needs explicit endpoints rather than burying proof cards in finding metadata:

| Endpoint | Purpose |
|---|---|
| `GET /api/validation-cards?engagement_id=...` | List proof cards for operator review. |
| `POST /api/validation-cards` | Create a redacted validation card from Hermes. |
| `GET /api/validation-cards/[id]` | Read one proof card with attempts and audit trail. |
| `PATCH /api/validation-cards/[id]` | Operator decision: approve, reject, needs-more-context, manually validated, false positive. |
| `POST /api/validation-cards/[id]/attempts` | Record a validation attempt result. |
| `GET /api/model-capabilities` | View cc-switch model capability records. |
| `PATCH /api/model-capabilities/[id]` | Operator promotion/restriction decision. |

All endpoints use server-side Supabase helpers and the same secure API wrapper pattern as hardened routes. Machine writes require `AGENT_TOKEN`; operator decisions require authenticated Portal session.

#### Portal view requirements

Portal must show proof data as a first-class operator view, not as hidden JSON:

| View | Required fields/actions |
|---|---|
| Finding detail | Linked validation card, proof ladder rung, validation action risk, expected positive/negative, stop conditions, UQLM score, model trace. |
| Proof queue | Cards sorted by severity, action risk, confidence, and age. Quick filters for `needs_more_context`, high-impact safe proof, and blocked risky proof. |
| Approval queue | Shows only cards/actions that crossed a policy boundary. Approve/reject requires reason. |
| Model capability dashboard | Model/profile/skill matrix with promotion state, scores, latency, failure rate, and last operator decision. |
| Audit trail | Route decision, UQLM decision, proof-card decision, validation attempt result, and operator decision in time order. |

cc-switch should remain the primary local operator console for fast work. Portal mirrors the redacted/cloud-safe state for dashboarding, review, and audit.

#### Acceptance criteria for schema/view work

- One canonical enum set is used across Python, Rust, TypeScript, SQL, and docs.
- Local DB can store raw/local-only proof material; Supabase receives only redacted fields and refs.
- Portal can display and decide proof cards without inspecting raw local registry values.
- Existing `action_class` and `risk_level` callers keep working through compatibility mapping during migration.
- Tests prove high-impact/read-only proof is not auto-quarantined while destructive/data-access proof is always blocked.

---

## Vulnerability Intelligence Pipeline

Every finding is enriched with real threat intelligence before reaching the operator. AI-generated text alone is not enough — findings must be grounded in standards-based vulnerability data and prioritized with operational decision logic.

### The 6-stage pipeline

```
Raw finding (scanner output, manual entry, pentest-ai-agents SQLite)
  │
  ├─ Stage 1: IDENTIFY — CVE + NVD
  │     Confirm CVE ID, product, affected version, CVSS/CPE metadata.
  │     NVD provides standards-based vulnerability data, impact metrics,
  │     product names, and automation data.
  │
  ├─ Stage 2: PRIORITIZE — CISA KEV + EPSS
  │     Decide whether to escalate. CISA KEV tracks vulnerabilities
  │     exploited in the wild; EPSS estimates exploitation probability
  │     over the next 30 days.
  │
  ├─ Stage 3: VALIDATE RELEVANCE — vendor advisory + asset inventory
  │     Check whether your environment actually runs the affected
  │     product/version. Filter out noise before it reaches the operator.
  │
  ├─ Stage 4: CLASSIFY ROOT CAUSE — CWE + OWASP ASVS/WSTG
  │     Classify the weakness and map to secure-code or testing control.
  │
  ├─ Stage 5: DECIDE ACTION — SSVC
  │     Convert findings into action: Track, Track*, Attend, or Act.
  │     CISA's SSVC uses decision points: exploitation status, technical
  │     impact, automatability, mission prevalence, and public well-being
  │     impact.
  │
  └─ Stage 6: RECOMMEND FIX — vendor advisory + OWASP guidance
        Produce patch, mitigation, config change, or secure-code
        recommendation.
```

### Low-noise rule

Do not ingest everything equally. Priority order:

| Priority | Condition | Action |
|----------|-----------|--------|
| **Highest** | CISA KEV match | Auto-escalate, immediate operator notification |
| **High** | EPSS high + exposed asset confirmed | Route to top of triage queue |
| **Medium** | CVSS high but no exploitation evidence | Normal triage |
| **Low** | No asset match | Suppress — don't show the operator noise |
| **Hold** | Only exploit reference, no vendor/CVE match | Queue for manual review, don't auto-ingest |

### Architecture

```
CVE/NVD → normalize
      ↓
Asset match → keep only relevant items
      ↓
KEV + EPSS → prioritize
      ↓
SSVC → decide action (Track / Track* / Attend / Act)
      ↓
CWE/OWASP → explain root cause
      ↓
Vendor advisory → fix recommendation
```

### Output fields

Clean, scannable output — no raw data dumps:

| Field | Source | Purpose |
|-------|--------|---------|
| CVE ID | NVD | Canonical identifier |
| Product | NVD CPE | Affected software name |
| Affected version | NVD CPE | Version range confirmed vulnerable |
| Fixed version | Vendor advisory | First patched version |
| Asset match | Internal inventory | Is this in our environment? |
| CVSS | NVD | Severity score (3.1) |
| EPSS | FIRST EPSS | Exploitation probability (0-1) |
| KEV | CISA KEV | Actively exploited: true/false |
| Exploit status | CISA KEV + vendor | Weaponized / PoC / none |
| CWE | NVD + CWE catalog | Weakness classification |
| Business criticality | Operator-defined | Impact on mission |
| Recommended action | SSVC | Track / Track* / Attend / Act |
| Source URL | NVD / vendor | Direct link to advisory |
| Last checked | System | When this data was fetched |

This gives AppSec, SOC, and management a clean result without flooding them with raw vulnerability data.

### Integration

```
Raw finding
  │
  ▼
LocalRedactionRegistry
  → sensitive values become stable refs
  → raw mapping stays local only
  │
  ▼
RedactedFindingBrief
  → cloud-safe structured brief
  → includes CVE/CWE/service shape/evidence summary/ref IDs
  │
  ▼
Fabric enrich_vuln_intel              ← NEW pattern
  → Stages 1-5: CVE, KEV, EPSS, CWE, SSVC
  → Outputs clean vuln intel metadata
  │
  ▼
Fabric enrich_finding                 ← existing pattern
  → Stage 6: AI-generated impact, remediation, reproduction_steps
  → Fills 6 missing Supabase fields with self-reported confidence
  │
  ▼
UQLM verification                     ← hallucination detection
  │
  ▼
POST /api/findings
  → enrichment-gate.ts
  → raw-value boundary checks
  → Supabase redacted record
  → Portal operator review
```

### Implementation: API-first + local SQLite cache

**Design principle:** API-first with small local cache, not full database download. The device stays light — query public APIs only when needed, store only matched results.

```
Agent
  ↓
Local asset inventory
  ↓
Small local SQLite cache
  ↓
Public APIs only when needed
  ↓
Store only relevant results
```

### Connection method by source

| Source | Best method | Store locally? |
|--------|------------|----------------|
| **NVD** | REST API query by CVE, CPE, product, or last modified date. Paginated responses for large collections. ([NVD](https://nvd.nist.gov/developers/vulnerabilities)) | Store only matched CVEs |
| **CISA KEV** | Download small JSON/CSV catalog. CISA provides KEV in JSON and CSV formats. ([CISA](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)) | Yes, full KEV is small enough |
| **EPSS** | API query by CVE ID via FIRST `/epss`. ([FIRST](https://api.first.org/epss/)) | Store CVE + score + percentile |
| **OSV.dev** | API query by package name, ecosystem, version, or commit. Supports batched queries. ([OSV](https://google.github.io/osv.dev/api/)) | Store only package matches |
| **GitHub Advisory DB** | Use GitHub API or OSV where possible | Store only dependency matches |
| **Vendor advisories** | Query only when CVE/product is relevant | Store URL, fixed version, mitigation |
| **CWE / OWASP** | Static reference data | Store small taxonomy subset |

### Local SQLite schema

SQLite is enough for a laptop, small VM, or endpoint agent. Use PostgreSQL only if many agents report to one central server.

```sql
-- What's installed in the environment
CREATE TABLE assets (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,           -- normalized product/package name
  version TEXT NOT NULL,        -- installed version
  ecosystem TEXT,               -- e.g., npm, pypi, maven, deb, rpm
  cpe_match TEXT,               -- mapped CPE string
  business_criticality TEXT,    -- low / medium / high / critical
  last_seen TEXT NOT NULL
);

-- Matched CVEs from NVD (only what's relevant)
CREATE TABLE vulnerability_cache (
  cve_id TEXT PRIMARY KEY,
  product TEXT NOT NULL,
  affected_version TEXT NOT NULL,
  fixed_version TEXT,
  cvss_score REAL,
  cvss_vector TEXT,
  cwe_id TEXT,
  source_url TEXT,
  last_checked TEXT NOT NULL
);

-- CISA KEV catalog (small, full mirror)
CREATE TABLE kev_cache (
  cve_id TEXT PRIMARY KEY,
  vendor_project TEXT NOT NULL,
  product TEXT NOT NULL,
  date_added TEXT NOT NULL,
  remediation_deadline TEXT,
  known_ransomware BOOLEAN DEFAULT 0,
  last_updated TEXT NOT NULL
);

-- EPSS scores for matched CVEs only
CREATE TABLE epss_cache (
  cve_id TEXT PRIMARY KEY,
  epss_score REAL NOT NULL,
  percentile REAL NOT NULL,
  last_updated TEXT NOT NULL
);

-- Open-source package matches from OSV
CREATE TABLE package_cache (
  id INTEGER PRIMARY KEY,
  package_name TEXT NOT NULL,
  ecosystem TEXT NOT NULL,
  affected_version TEXT NOT NULL,
  fixed_version TEXT,
  cve_id TEXT,
  osv_id TEXT,
  last_checked TEXT NOT NULL
);

-- When each source was last refreshed
CREATE TABLE source_refresh_log (
  source TEXT PRIMARY KEY,
  last_refreshed TEXT NOT NULL,
  items_fetched INTEGER,
  status TEXT
);
```

### What NOT to store

Keep the device light. Do NOT store:

```
Full NVD mirror
Full exploit database
Full advisory archive
Raw HTML pages
All historical EPSS scores
Full ATT&CK/CAPEC unless explicitly needed for an engagement
```

### Noise-control rules

Filter BEFORE storing:

| Rule | Action |
|------|--------|
| `asset_match = true` | Store |
| `KEV = true` | Store regardless of asset match |
| `EPSS >= chosen threshold` | Store |
| Package/version confirmed affected | Store |
| No affected product match | Ignore |
| Only keyword match (no CVE/CPE) | Ignore |
| Cache older than 7 days without recheck | Expire |
| Cache older than 30 days | Delete |

### Refresh schedule

| Data | Refresh |
|------|---------|
| Asset inventory | Daily or on software change |
| CISA KEV | Daily (full catalog is small) |
| EPSS | Daily for matched CVEs |
| NVD | Daily for matched products or CVEs |
| OSV/GitHub advisories | Daily for detected packages |
| Vendor advisory | Only when CVE is relevant |

### Minimal execution flow

```
1. Collect installed software / packages
2. Normalize names to CPE or package ecosystem
3. Query OSV for open-source packages
4. Query NVD only for matched CPE/product
5. Check KEV and EPSS only for matched CVEs
6. Store final enriched findings only
7. Delete stale unmatched data
```

### Multi-device architecture (optional)

For teams running multiple agents:

```
Endpoint agent → sends software/package list only
Central enrichment service → queries NVD, KEV, EPSS, OSV
Central DB → stores enriched results
Endpoint agent ← receives only relevant findings
```

This keeps endpoint installs small and avoids each device repeatedly calling public APIs. For single-operator use, SQLite on the laptop is sufficient.

## Data Flow

### Full enrichment pipeline

```
Raw finding data (from scanner, pentest-ai-agents SQLite, or manual)
  │
  ▼
Sensitivity classification
  → raw_local_only / redacted_cloud_ok / public
  │
  ▼
Local redaction pass
  → Stable refs for domains, IPs, URLs, secrets, PII, tenant/customer names
  → Local registry stores ref -> real value
  → RedactedFindingBrief is created for cloud-safe reasoning and storage
  │
  ▼
Vuln Intel Pipeline (Fabric enrich_vuln_intel)
  1. Collect installed software → normalize to CPE/ecosystem
  2. Query OSV for open-source packages
  3. Query NVD for matched CPE/product → store matched CVEs in SQLite
  4. Check KEV + EPSS for matched CVEs
  5. Apply noise-control rules → suppress non-matches
  6. Run SSVC → Track / Track* / Attend / Act
  │
  ▼
Fabric enrich_finding (existing)
  → AI-generated impact, remediation, reproduction_steps
  → Self-reported confidence per field
  → If cloud model is used, prompt contains RedactedFindingBrief only
  │
  ▼
UQLM verification (uqlm_verify.py)
  → BlackBoxUQ + LongTextUQ independent scoring
  → Local raw verification allowed only inside local boundary
  → Cloud-assisted output verified against redacted brief
  │
  ▼
POST /api/findings (redacted finding + vuln_intel + confidence metadata)
  │
  ▼
enrichment-gate.ts
  → Layer 1: Fabric self-reported confidence
  → Layer 2: UQLM independent verification
  → Layer 3: sensitive-data boundary check
  │
  ▼
Supabase (redacted draft finding, flagged if uncertain)
  │
  ▼
Portal — operator sees threat intel + confidence profile, triages
  │
  ▼
cc-switch / local CLI — rehydrates refs for operator-only manual testing
```

### UQLM integration point

```
hermes-agent/scripts/
  uqlm_verify.py          ← NEW: wraps UQLM for enrichment verification
  offensive-research-portal-task-runner.py ← MODIFY: calls uqlm_verify after Fabric, before API POST
```

`uqlm_verify.py` exposes one async function:

```python
async def verify_enrichment(
    enrichment_prompt: str,      # full Fabric prompt
    enrichment_output: dict,     # Fabric's JSON output
    model: str = "qwen2.5:32b"   # model for UQLM scoring
) -> dict:
    """Returns { uqlm: { semantic_negentropy, noncontradiction, ... } }
    for merging into metadata.confidence before POST /api/findings."""
```

### Model routing
Task assigned → Hermes classifies data sensitivity → cc-switch matches skill tag, required capability tags, quality floor, and sensitivity policy → routes to best allowed provider → circuit-breaks on failure → delegates to next allowed provider → alerts operator on limits.

If the task contains raw sensitive evidence, cc-switch may only return a local provider. If no local provider is capable enough, Hermes must redact first or stop for operator review. Cloud fallback is allowed only after the payload is transformed into a `RedactedFindingBrief`.

Routing is also capability-gated. A provider tag such as `analysis`, `exploit`, or `report` is only a claim until that model has an approved capability record for the skill. Public benchmarks may influence candidate selection, but runtime routing uses local capability records, sensitivity policy, and action-risk policy.

### Report generation
Operator clicks "Generate Report" → Portal creates task → Hermes claims → Fabric writes report → Hermes POSTs to Supabase → Portal shows download.

**Portal UI never executes tasks directly.** It creates tasks that Hermes picks up, and Portal API routes persist authorized records to Supabase with server-side credentials. Every execution path stays: local executes → Portal API writes → Supabase stores → Portal reads.

---

## Data Durability & Resilience

### Write ordering — how data is never lost

Every piece of data follows a strict write order. Local SQLite is the operational source of truth. Supabase is the remote source of truth after confirmed sync.

```
1. WRITE local     → pentest-ai-agents SQLite (WAL mode, synchronous)
                      Same transaction: finding + sync_queue entry
                      At this point data IS durable — SQLite is on disk.

2. QUEUE sync       → sync_queue table (same transaction as step 1)
                      Status: 'pending' | 'syncing' | 'synced' | 'failed'

3. SYNC remote      → POST to Supabase (async, with retry + backoff)
                      Fingerprint prevents duplicate inserts on retry.

4. CONFIRM sync     → UPDATE sync_queue SET status='synced'
                      Only after Supabase returns 201.

5. GC local         → DELETE FROM sync_queue WHERE status='synced' AND age > 7d
                      Keep synced records for a week as audit trail.
```

### Write-ahead log (WAL)

`pentest-ai-agents/db/schema.sql` already enables `PRAGMA journal_mode=WAL`. This means:

- Writers don't block readers — Hermes can write findings while the operator queries via cc-switch
- If the process crashes mid-write, the WAL recovers on next open — no corruption
- The WAL file is on the same disk — survives process death, survives power loss (with fsync)
- Automatic checkpointing moves WAL pages back to the main database

### What survives what

| Failure | What's in SQLite | What's in Supabase | Data lost? |
|---------|-----------------|-------------------|------------|
| Process crash mid-write | WAL recovers on reopen | Nothing written yet | No — WAL recovery |
| Process crash after write, before sync | Finding + sync_queue row (pending) | Nothing | No — sync resumes on restart |
| Internet drops for 10 minutes | Finding + sync_queue (pending) | Nothing | No — sync retries when back |
| Internet drops for 3 days | Finding + sync_queue (pending) | Nothing | No — but operator should check disk space |
| Disk fills up | SQLite returns SQLITE_FULL | N/A | Yes — Hermes pauses, alerts operator |
| SQLite file corrupted | WAL may recover; otherwise need backup | Everything previously synced | Partial — unsynced items lost if DB unrecoverable |
| Laptop stolen / disk destroyed | All gone | Everything synced before the event | Partial — only unsynced findings lost |

### One database, not four

```
pentest-ai-agents/db/findings.db  ← single SQLite file on disk
  │
  ├─ Findings tables (existing)
  │   engagements, hosts, services, vulns,
  │   credentials, loot, chains, session_log
  │
  ├─ Vuln intel cache (NEW)
  │   assets, vulnerability_cache, kev_cache,
  │   epss_cache, package_cache, source_refresh_log
  │
  └─ Sync queue (NEW)
      sync_queue — pending Supabase writes
      checkpoint  — Hermes task progress
```

cc-switch keeps its own SQLite for management-plane data (providers, routing, circuit state). Two databases total. Two concerns. Two failure domains.

### Sync queue schema

```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,     -- 'finding', 'host', 'service', 'report'
  entity_id TEXT NOT NULL,       -- UUID of the entity
  payload TEXT NOT NULL,         -- Full JSON payload to POST
  fingerprint TEXT,              -- Idempotency key
  endpoint TEXT NOT NULL,        -- /api/findings, /api/engagements/../hosts
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'syncing', 'synced', 'failed', 'dead')),
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 8,
  next_retry_at TEXT,            -- ISO timestamp for exponential backoff
  last_error TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  synced_at TEXT
);

CREATE INDEX idx_sync_queue_status ON sync_queue(status, next_retry_at);
```

### Sync worker behavior

```
Every 5 seconds:
  1. SELECT * FROM sync_queue WHERE status='pending' AND next_retry_at <= now()
     ORDER BY created_at LIMIT 10

  2. For each row:
     a. UPDATE status='syncing'
     b. POST to Supabase (with fingerprint header)
     c. If 201 → UPDATE status='synced', synced_at=now()
     d. If 409 (conflict/duplicate) → UPDATE status='synced' (idempotent)
     e. If 4xx → UPDATE status='dead' (bad payload, don't retry)
     f. If 5xx or timeout → UPDATE status='pending',
        retry_count++, next_retry_at = exponential backoff
     g. If retry_count >= max_retries → UPDATE status='dead'

  Dead-letter handling:
    SELECT * FROM sync_queue WHERE status='dead'
    → Operator reviews via cc-switch
    → Can manually retry or discard
```

### Hermes checkpoint for crash recovery

```sql
CREATE TABLE checkpoint (
  task_id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL,
  processed INTEGER NOT NULL DEFAULT 0,   -- how many findings processed
  total INTEGER,                           -- total findings in this task
  last_fingerprint TEXT,                   -- last successfully written fingerprint
  status TEXT NOT NULL DEFAULT 'running'
    CHECK (status IN ('running', 'completed', 'failed')),
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

On task start: `INSERT INTO checkpoint (task_id, run_id, total)`. After each finding: `UPDATE checkpoint SET processed=N, last_fingerprint=X`. On requeue: `SELECT * FROM checkpoint WHERE task_id=X` → resume from `processed`.

### Ingestion Defense — Three-Layer Gate

**Layer 1 — Self-Reported Confidence (Fabric):** Enforced at API boundary by `lib/enrichment-gate.ts`:

| Overall Confidence | Action |
|---|---|
| `< 0.3` | **REJECT** (422) |
| `0.3 – 0.5` | **ROUTE TO REVIEW** (`review_required` forced) |
| `≥ 0.5` | **PASS** (field-level warnings if any field < 0.3) |
| No data | **ACCEPT** (raw/manual, `review_required` forced) |

Human-reviewed findings bypass auto-rejection but still receive warnings.

**Layer 2 — Independent Verification (UQLM):** Applied to HIGH/CRITICAL findings.

| Fabric self-report | UQLM score | Gate decision |
|---|---|---|
| High (0.85) | High (0.82) | PASS — consensus |
| High (0.85) | Low (0.25) | ROUTE TO REVIEW — confident hallucination |
| Low (0.35) | High (0.78) | ROUTE TO REVIEW — Fabric uncertain |
| Low (0.35) | Low (0.30) | REJECT — both agree it's bad |

**Layer 3 — Sensitive Evidence Boundary:** Applied to all cloud-bound writes and cloud-model calls.

| Payload state | Gate decision |
|---|---|
| Raw sensitive values present in cloud-bound fields | REJECT or QUARANTINE before upload/call |
| Stable refs present, local registry exists | PASS to cloud-safe reasoning/storage |
| Stable refs present, local registry missing | ROUTE TO REVIEW because operator cannot rehydrate |
| Operator explicitly marks value shareable | PASS with audit record |

Layer 3 prevents privacy failure. Layers 1 and 2 prevent low-quality or hallucinated findings. All three gates are advisory to the operator workflow but fail closed at automation boundaries.

### Idempotency

Single canonical fingerprint: `SHA256(engagement_id + vuln_type + affected_url + title)`. Enforced at API layer + UNIQUE constraint at database level. Sync worker sends fingerprint as header. Supabase returns 409 on duplicate → sync worker marks synced (not failed).

### Complete failure matrix

| Failure | Data durability | Recovery |
|---------|---------------|----------|
| Process crash mid-write | WAL recovery on SQLite reopen | No loss |
| Process crash after write, before sync | Finding in SQLite, sync_queue.pending | Sync worker resumes on restart |
| Internet drops (minutes to days) | All findings in local SQLite | Sync worker drains queue when back |
| Supabase returns 5xx | Sync_queue.pending, exponential backoff | Retries up to 8 times, then dead-letter |
| Supabase returns 409 (duplicate) | Already synced by another attempt | Mark synced, don't retry |
| Disk full | SQLITE_FULL, Hermes pauses | Operator frees space, resumes |
| SQLite corruption | WAL may auto-recover | If unrecoverable: restore from Supabase (already synced) + re-run unsynced tasks |
| Laptop destroyed | All local data gone | Supabase has everything synced. Re-clone, re-run last task. |

---

## Operator Authority Policy

This policy cannot drift, be overridden by model routing, or bypassed by failover logic.

### Core Rules

1. Hermes operates with adversarial reasoning. It MAY think like an attacker.
2. Hermes is execution-constrained by policy.
3. High/Critical findings require careful proof design, not automatic denial.
4. High-risk validation actions require explicit operator approval before execution.
5. Approval is **action-level**, not only finding-level.
6. No background auto-escalation.
7. Model routing failover may NOT bypass approval requirements.
8. Out-of-scope targets are hard-blocked regardless of model recommendation.
9. Policy evaluation failure → default DENY.
10. All approval/rejection decisions are immutable, timestamped, and audited in `audit_log`.

### Action-Level Risk Classification

| Action Class | Examples | Approval Required |
|---|---|---|
| **Passive** | Enumerate, fingerprint, collect headers, DNS lookup | Never |
| **Active read-only** | `GET`/`HEAD`, unauthenticated baseline, metadata fetch, safe version check | Allowed inside approved scope/workflow with rate limits; notify on High/Critical hypothesis |
| **Active non-destructive differential** | Authorized vs unauthenticated compare, invalid-token compare, benign boolean probe, strict timeout | Allowed only if pre-approved for the workflow; otherwise ask |
| **Controlled canary/OOB** | Operator-owned callback, harmless marker, no internal pivot | Requires configured owned callback and audit record; ask if not pre-approved |
| **Reversible state-changing** | Create disposable test object, modify test-only account, restore immediately | **Ask operator** |
| **Destructive / data-access / DoS / persistence** | Dump data, delete/modify real data, crash service, high-load timing, exploit chain, persistence | **Always ask operator or lab-only** |

### Trust Boundaries

| Action | Who |
|--------|-----|
| Approve high-risk actions | Operator only |
| Confirm/reject findings | Operator only |
| Generate reports | Operator only |
| Edit workflow/scope/policies | Operator only |
| Manage model pool | Operator only |
| View findings/reports | Operator (authenticated) |
| Execute approved tasks | Hermes (constrained by policy) |
| Write draft findings | Hermes (always as `draft`) |
| Route models | cc-switch (automated, logged) |
| Verify enrichment quality | UQLM (automated, advisory to gate) |

### Two Approval Gates

**Gate 1 — Workflow Review:** Create engagement → cc-switch shows plan → scope validated → operator reviews, edits → approves. Nothing runs without this.

**Gate 2 — Proof Review / Action Quarantine:** Hermes enumerates → builds validation card → separates `vulnerability_severity` from `validation_action_risk` → chooses lowest-risk proof rung → if proof is passive/read-only and inside the approved workflow, Hermes may continue with logging and notification → if proof escalates to reversible state change, destructive behavior, data access, DoS, out-of-scope ambiguity, or weak evidence on a high-impact hypothesis, Hermes stops → Portal/cc-switch shows finding + proposed action + risk class → operator approves/blocks → decision immutable, logged → if approved, Hermes validates.

---

## UQLM Integration Plan

UQLM verifies quality; it does not decide authorization and it does not require cloud exposure of raw evidence. The scorer input depends on the sensitivity boundary:

| Flow | UQLM input | Expected output |
|---|---|---|
| Local-only raw analysis | Raw finding + local enrichment output | Score whether local reproduction steps are grounded and noncontradictory |
| Cloud-assisted analysis | RedactedFindingBrief + cloud-generated template | Score whether the template is consistent with the brief and does not invent hidden raw facts |
| Operator review | Rehydrated local finding + evidence | Help explain uncertainty, but operator makes the decision |

For high-likelihood, high-impact findings, UQLM should reduce review noise by flagging unsupported claims and weak reproduction steps before the operator spends time testing them.

### Scorer-to-field mapping

| Enrichment field | Type | Primary scorer | Secondary | Rationale |
|-----------------|------|---------------|-----------|-----------|
| `vuln_type` | Short classification | `semantic_negentropy` | `entailment` | Must be consistent across 5 runs |
| `cwe_id` | Code | `exact_match` | `semantic_negentropy` | Deterministic string |
| `cvss_vector` | Structured string | `cosine_sim` | `semantic_negentropy` | Embedding similarity |
| `affected_url` | URL | `exact_match` | `cosine_sim` | Extracted from input, not invented |
| `impact` | Long narrative | `LongTextUQ` (entailment) | `noncontradiction` | Per-claim verification |
| `remediation` | Long narrative | `LongTextUQ` (entailment) | `noncontradiction` | Per-claim verification |
| `reproduction_steps` | Structured list | `LongTextUQ` (entailment) | `cosine_sim` | Step consistency |
| Overall | Full JSON | `semantic_negentropy` | `LLMPanel` | Cross-generation agreement |

### Files to create or modify

| # | File | Action |
|---|------|--------|
| 1 | `hermes-agent/scripts/uqlm_verify.py` | Create — wraps BlackBoxUQ + LongTextUQ for enrichment verification |
| 2 | `hermes-agent/scripts/offensive-research-portal-task-runner.py` | Modify — call uqlm_verify after Fabric, before API POST |
| 3 | `offensive-research-portal/report-viewer/lib/enrichment-gate.ts` | Modify — add Layer 2 UQLM score interpretation |
| 4 | `offensive-research-portal/report-viewer/lib/__tests__/enrichment-gate.test.ts` | Modify — add UQLM Layer 2 test cases |
| 5 | `hermes-agent/Dockerfile.gateway` | Modify — install uqlm + langchain-ollama |

### UQLM initialization pattern (from tests)

```python
from uqlm import BlackBoxUQ, LongTextUQ
from langchain_ollama import ChatOllama

llm = ChatOllama(model="qwen2.5:32b", temperature=1.0)

# Short fields: single async call, multiple scorers
bbuq = BlackBoxUQ(llm=llm, scorers=[
    "semantic_negentropy",
    "noncontradiction",
    "cosine_sim",
], device="cuda")

# Long fields: claim-level with conservative aggregation
luq = LongTextUQ(llm=llm,
    granularity="claim",
    aggregation="min",          # flag if ANY claim fails
    response_refinement=True,   # strip low-confidence claims
    scorers=["entailment", "noncontradiction"],
)

# Both return UQResult with .to_df() for DataFrames
# or .data dict for JSON serialization
```

### API surface (confirmed from test data)

- `BlackBoxUQ.generate_and_score(prompts, num_responses)` → `UQResult`
  - `.to_df()` columns: `prompts`, `responses`, `sampled_responses`, plus one column per scorer
  - `.data` dict: same as above as lists
  - `.metadata` dict: `temperature`, `sampling_temperature`, `num_responses`, `scorers`
- `LongTextUQ.generate_and_score(prompts, num_responses)` → `UQResult`
  - `.data` includes: `responses`, `sampled_responses`, one list per scorer, `claims_data`, `refined_responses` (if response_refinement=True)
  - `.metadata` includes: `mode`, `granularity`, `aggregation`, `temperature`, `num_responses`
- `LLMPanel.generate_and_score(prompts)` → `UQResult`
  - `.data`: `prompts`, `responses`, `judge_N` per judge, `avg`, `max`, `min`, `median`
  - Supported judge types: `LLMJudge` instances or `BaseChatModel` (auto-converted)

---

## Current Build State

### cc-switch
cc-switch is the owner of provider/model routing and skill management. The active Rust router lives in `cc-switch/src-tauri/src/proxy/providers/router.rs` and supports provider pools, circuit breakers, task complexity, capability tags, and local/cloud provider metadata. The local HTTP proxy exposes `POST /cc-switch/models/route` from `cc-switch/src-tauri/src/proxy/handlers.rs`; Hermes asks that endpoint for a model decision before execution.

Applied pattern:

- **Policy owner:** cc-switch owns model-selection policy.
- **Local-first strategy:** local providers are preferred only when they meet the required capability tags and quality floor; cloud providers are fallback, not the default.
- **Adapter boundary:** `src/lib/api/model-router-adapter.ts` logs an already selected model to Portal; it does not ask Portal to choose.
- **Safety invariant:** model failover does not bypass scope, risk, or approval rules.

Code audit notes:

- `route_step` derives required tags from the skill name (`analysis`, `recon`, `report`, `exploit`) before LocalFirst selection.
- Model hints are honored only when the hinted provider still satisfies the complexity floor and required tags.
- `route_step_with_policy` and `route_request_with_policy` now apply `data_sensitivity`, `validation_action_risk`, `promotion_state`, and required capability tags before strategy selection.
- `raw_local_only` requests fail closed unless an eligible local provider can satisfy the skill; cloud fallback is not allowed for raw local-only evidence.
- `candidate`, `shadow`, and `disabled` model profiles are excluded from execution. `restricted` and `approved` are selectable only when policy and tags match.
- Exploit-capable profiles are excluded from normal analysis/report tasks unless the requested skill or action policy requires exploit capability.
- The cc-switch GUI proxy defaults to loopback (`127.0.0.1:15721`). Docker-based Hermes proofs use the headless cc-switch model router so `hermes-gateway` can reach `/cc-switch/models/route` without the GUI/Tauri stack.
- Model-route proof is green locally as of 2026-05-24: Hermes asks cc-switch for a LocalFirst decision, logs it through Portal `/api/models/route` with `AGENT_TOKEN`, and Supabase persists both `model_selections` and `model_routing_results` rows.
- Sensitive routing core is implemented as of 2026-05-25 in both the GUI proxy route and the headless router. Remaining work is operational proof with real provider records and dashboard visibility, not the core selection rule.

### Hermes
Gateway heartbeat, task claim, receipt mode, and the local task bridge are working. Verified on 2026-05-23 with receipt proof task `5261ad04-6014-4453-8ff2-d8c736ffeca4`. Analysis mode with Fabric enrichment, quarantine child-tasks, action classification, and browser validation lives in `offensive-research-portal-task-runner.py`. Vuln intel enrichment lives in `vuln_intel_adapter.py`. UQLM Layer 2 verification lives in `uqlm_verify.py`. Offline sync is implemented in `sync_worker.py`. Fingerprint handling is standardized.

Current model-routing flow:

```text
Hermes task runner
  -> cc-switch POST /cc-switch/models/route
  -> selected_model/model_identifier returned
  -> Hermes logs the selected decision to Portal POST /api/models/route
  -> Portal persists model_selections + model_routing_results
```

Hermes keeps `ORP_AGENT_MODEL` only as a fallback when cc-switch routing is disabled or unreachable.

Sensitive-evidence gap:

- The task runner now has a local JSON `LocalRedactionRegistry` at `ORP_REDACTION_REGISTRY_PATH` or `~/.hermes/orp_redaction_registry.json`.
- It still needs a `RedactedFindingBrief` builder before cloud model calls or Portal writes.
- It now tags model-route requests with `data_sensitivity`; cc-switch enforces that field before provider selection.
- It now has a rehydration helper for local operator tooling; UI/CLI wiring is still pending.

### Fabric
Fabric CLI v1.4.452 is installed. Five custom patterns exist under `hermes-agent/fabric-patterns/` and are copied into the Hermes gateway image by `hermes-agent/Dockerfile.gateway`:

- `csp_evaluation`
- `enrich_finding`
- `enrich_vuln_intel`
- `pentest_finding_draft`
- `pentest_report`

Remaining proof: run the patterns against real finding material through Hermes/Fabric and record the result in Portal.

### UQLM
Library cloned at `uqlm/` (v0.5.11, Apache 2.0). Adapter built (`uqlm_verify.py`) with BlackBoxUQ + LongTextUQ wrappers, field-level scorer configuration per engagement, and composite scoring. Layer 2 cooperative gate is wired in `enrichment-gate.ts`. Dependencies are opt-in through `HERMES_GATEWAY_INSTALL_UQLM_DEPS=true`; the default Docker Compose proof image skips UQLM so the gateway does not pull heavy Torch/NVIDIA packages during receipt-mode verification. The mounted `uqlm/` checkout is installed at boot only when that flag is enabled.

Remaining UQLM alignment work:

- Add tests for scoring redacted reproduction templates.
- Ensure UQLM prompts do not require raw target values when the flow is cloud-assisted.
- Keep UQLM decisions as review/refine/reject signals, never as approval to execute.

### Portal
Portal is the read/write API boundary for Supabase and the read dashboard for operator review. It does not own final model-selection policy. Current model APIs exist for config, selection, usage, summary, and decision logging.

Current model-routing boundary:

- `report-viewer/lib/model-router.ts` has been removed.
- `POST /api/models/route` is a logging endpoint only. It rejects requests that do not include `selected_model`/`model_identifier`.
- The endpoint writes `model_selections` for task-level model choice and `model_routing_results` for routing audit history.
- The route is wrapped with the secure API handler, standard rate limiting, and security headers.

Known drift to fix next:

- Consolidate naming so `skill_tag` is the primary workflow field and `task_type` is only compatibility input.
- Keep the model dashboard aligned with the logging tables: proof rows are stored in `model_selections` and `model_routing_results`, while token/cost telemetry is stored separately in `model_usage`.
- Decide whether `model_configs` remains persisted only through Portal APIs or is also synced directly from cc-switch's local provider store.
- Add sensitive-data boundary checks to finding/report write paths so raw private targets, secrets, and PII cannot be silently persisted to cloud storage.
- Add explicit tests proving Portal accepts redacted refs and rejects/quarantines obvious raw sensitive values.

### Supabase
`offensive-research-portal/supabase/schema.sql` is the canonical schema source. It currently defines 19 tables with RLS deny-all plus service-role server access. `offensive-research-portal/supabase/model-tables.sql` is a historical Phase 5 extraction and must not be used as the canonical schema because it duplicates a subset of `schema.sql` and lacks the safe migration logic now present there.

Canonical model-related names:

| Name | Meaning |
|---|---|
| `skill_tag` | Workflow/Hermes skill identifier. Prefer this over new ad hoc `task_type` routing inputs. |
| `task_type` | Legacy route compatibility field. Map it from `skill_tag` until Portal route/schema naming is consolidated. Do not add new routing logic around this name. |
| `model_identifier` | Provider model ID, for example an Ollama/OpenRouter/Gemini model string. |
| `selected_model` | Model chosen for a workflow step or agent task. |
| `routed_model` | Routing audit output only; written to `model_routing_results`. |

Duplicate/stale model schema warning:

- `offensive-research-portal/supabase/schema.sql` is canonical.
- `offensive-research-portal/supabase/model-tables.sql` and `offensive-research-portal/model-tables.sql`, if present, are historical extracts only. Do not apply them as migrations without reconciling against `schema.sql`.

### Code Pattern Strategy

Use these patterns for the next implementation steps:

| Boundary | Pattern | Rule |
|---|---|---|
| cc-switch routing | Strategy + adapter | Router strategies choose models; adapters only call or log decisions. |
| Portal APIs | Thin controller + service function | API routes validate, authorize, call Supabase helpers, and return safe responses. No orchestration policy. |
| Hermes execution | Orchestrator + port adapter | Task runner calls local ports (`cc-switch`, Fabric, UQLM, Portal API) and records events after each boundary. |
| Supabase writes | Repository/helper functions | All database writes stay behind server-side helpers using `SUPABASE_SERVICE_ROLE_KEY`. |
| Safety checks | Default-deny guard | Scope, risk, approval, and hallucination gates fail closed before execution or write. |
| Naming cleanup | Anti-corruption layer | Accept legacy fields at boundaries, normalize internally to canonical names, and stop propagation of old terms. |
| Sensitive evidence | Redaction registry + DTO | Convert raw findings into `RedactedFindingBrief` before cloud boundaries; local rehydration is operator-only. |
| Cloud model use | Template generation | Cloud models produce parameterized strategies and test templates against refs, not raw target-bound commands. |

### Vuln Intel Pipeline
Schema and adapters are built. `enrich_vuln_intel` exists as a Fabric pattern. `vuln_intel_adapter.py` supports NVD, CISA KEV, EPSS, OSV, retry, source-specific rate limiting, circuit breaking, Playwright fallback for vendor HTML, SQLite cache read/write, and mirror mode for KEV plus recent NVD keyword fetches.

### Safety & Resilience
Layer 1 + Layer 2 hallucination gates are built. UQLM scores are written to `audit_log`. Idempotency is built. Crash recovery schema and local sync queue exist, and `sync_worker.py` is present. Layer 3 sensitive-data boundary checks are now partially implemented: Hermes redacts cloud-bound analysis payloads, the sync worker rejects raw private targets/secrets before POST, and Portal finding/export/report routes fail closed when stored content contains raw private target or secret material. Portal Supabase helpers degrade missing optional read tables to empty lists, but missing-table writes must fail honestly so the local queue does not mark unsaved records as synced. Remaining proof is operational: run the full offline-buffer drain and Supabase reconciliation path under a controlled test on a feature branch before any main merge.

Detailed phase tracking: `offensive-research-portal/plan.md` (Phase 0-12)

---

## Implementation Blueprint — Decision Layer

This is the implementation plan for the logic change from severity-only quarantine to proof-driven validation. Build it in slices so the current stack keeps working while the new decision layer comes online.

### Slice 0 — Compatibility Constants

Status as of 2026-05-24: started in Hermes. Python constants and compatibility mapping now exist in the task runner. Rust, TypeScript, and SQL canonical enum definitions are still pending.

Goal: introduce canonical names without breaking existing tasks.

Files:

| Repo | Files |
|---|---|
| `hermes-agent` | `scripts/offensive-research-portal-task-runner.py`, new `scripts/proof_policy.py` if the helper grows |
| `offensive-research-portal` | `report-viewer/lib/types.ts`, `supabase/schema.sql` |
| `cc-switch` | router request/response structs and API handler types |

Add shared enum values in each language:

```text
DataSensitivity = raw_local_only | redacted_cloud_ok | public
ValidationActionRisk = passive | active_read_only | active_non_destructive_differential | controlled_canary | reversible_state_change | destructive_or_data_access
OperatorDecision = pending | approved | rejected | needs_more_context | manually_validated | false_positive
PromotionState = candidate | shadow | approved | restricted | disabled
```

Compatibility mapping:

```text
action_class=passive                  -> validation_action_risk=passive
action_class=active_non_destructive   -> validation_action_risk=active_read_only by default
action_class=active_destructive       -> validation_action_risk=destructive_or_data_access
risk_level                            -> vulnerability_severity only when finding severity is missing
```

Do not remove `action_class` yet. Keep it as a derived compatibility field until Portal, Hermes, cc-switch, tests, and schema are all migrated.

Tests:

- Unit test compatibility mapping.
- Unit test that unknown values fail closed to `destructive_or_data_access` or review-required.

### Slice 1 — Hermes Proof Cards In Metadata

Status as of 2026-05-24: implemented in Hermes for the metadata-backed path. The task runner now builds validation cards, stores them in finding metadata, forwards route trace into the card, and gates quarantine by `validation_action_risk` instead of severity alone. Focused proof-policy tests were added in `hermes-agent/tests/test_task_runner_proof_policy.py`.

Goal: fix the incorrect runtime behavior before adding new tables.

Initial implementation may store the validation card inside finding metadata:

```json
{
  "validation_card": {
    "hypothesis": "...",
    "observed_evidence": [],
    "standards_mapping": {},
    "vulnerability_severity": "high",
    "validation_action_risk": "active_read_only",
    "proof_ladder_rung": 1,
    "lowest_risk_proof": {},
    "expected_positive": "...",
    "expected_negative": "...",
    "stop_conditions": [],
    "data_sensitivity": "redacted_cloud_ok",
    "model_trace": {}
  }
}
```

Hermes implementation steps:

1. Add `classify_data_sensitivity(raw, enrichment, task)`.
2. Add `classify_validation_action_risk(steps, allowed_actions, vuln_type)`.
3. Add `proof_ladder_rung(validation_action_risk)`.
4. Add `build_validation_card(raw, enrichment, task, route, uqlm_result)`.
5. Add `requires_quarantine(vulnerability_severity, validation_action_risk, data_sensitivity, proof_card)`.
6. Include `metadata.validation_card` in the `/api/findings` payload.
7. Create quarantine tasks only when action risk crosses the policy boundary.

Required policy behavior:

| Case | Expected behavior |
|---|---|
| High severity + passive proof | Save draft finding, mark review required, no quarantine task |
| Critical severity + read-only proof | Save draft finding, notify/review, no action quarantine unless workflow policy says ask |
| Medium severity + destructive proof | Save draft finding and create quarantine task |
| Any severity + data access/DoS/persistence | Create quarantine task |
| Unknown action risk | Default to quarantine |
| Out-of-scope or scope unknown | Default to quarantine |

Tests:

- `requires_quarantine('critical', 'active_read_only') == false` when scope is confirmed and workflow allows read-only validation.
- `requires_quarantine('low', 'destructive_or_data_access') == true`.
- High-impact safe proof includes stop conditions and expected positive/negative signals.
- Validation card is present in finding metadata.

### Slice 2 — Supabase Schema And Portal APIs

Status as of 2026-05-25: first pass implemented in Portal and Hermes. Supabase schema now defines `validation_cards`, `validation_attempts`, `model_capability_records`, plus compatibility columns on `agent_tasks` and `workflow_steps`. Portal now has validation-card, validation-attempt, and model-capability API routes, with agent-token machine writes for validation-card creation/attempt logging, model-capability sync, and submission create/update. Viewer-auth protected reads/updates remain available for operator routes. Hermes now keeps the metadata compatibility path and also performs best-effort first-class `POST /api/validation-cards` sync for cloud-safe cards. Portal typecheck and full `report-viewer` Vitest suite are green at this checkpoint. Remaining work: wire UI views and prove the offline sync reconciliation path against the real schema.

Goal: move proof cards from metadata into first-class records.

Supabase changes:

1. Add `validation_cards`.
2. Add `validation_attempts`.
3. Add `model_capability_records`.
4. Add nullable compatibility columns to `agent_tasks` and `workflow_steps`:
   - `data_sensitivity`
   - `validation_action_risk`
   - `proof_ladder_rung`
   - `validation_card_id`
5. Add compatibility indexes for queue views:
   - `(engagement_id, status, created_at desc)` on `validation_cards`
   - `(validation_action_risk, vulnerability_severity)` on `validation_cards`
   - `(model_identifier, skill_tag, promotion_state)` on `model_capability_records`

Portal API changes:

| Endpoint | First implementation |
|---|---|
| `POST /api/validation-cards` | Agent-token machine write. Accepts redacted payload only. |
| `GET /api/validation-cards` | Authenticated operator list with filters. |
| `GET /api/validation-cards/[id]` | Detail view data. |
| `PATCH /api/validation-cards/[id]` | Operator decision and notes. |
| `POST /api/validation-cards/[id]/attempts` | Agent-token attempt result write. |
| `GET /api/model-capabilities` | Operator dashboard data. |
| `POST /api/model-capabilities` | Agent-token capability-record sync from measured local results. |
| `PATCH /api/model-capabilities/[id]` | Operator promotion/restriction. |
| `POST /api/submissions` | Agent-token submission sync write. |
| `PATCH /api/submissions/[id]` | Agent-token submission status sync write. |

Rules:

- Portal API validates canonical enums.
- Portal API rejects obvious raw secrets/private target values unless `data_sensitivity=public` and operator share flag exists.
- Machine writes require `AGENT_TOKEN`.
- Operator decisions require authenticated Portal session.
- Missing optional read tables may return an empty list during schema rollout; missing write tables must not return stub success because that would lose sync-worker data.

Tests:

- Route tests for unauthenticated 401.
- Route tests for invalid enum 400.
- Route tests for redacted card accepted.
- Route tests for raw private IP/secret rejected or quarantined.

### Slice 3 — Portal Views

Goal: make the proof layer visible and useful to the operator.

Views:

| View | Minimum implementation |
|---|---|
| Proof queue | Table grouped by severity and action risk, filters for `pending`, `needs_more_context`, high-impact safe proof, blocked risky proof. |
| Finding detail proof panel | Shows validation card, expected positive/negative, stop conditions, attempts, UQLM score, model trace. |
| Approval queue | Shows only policy-boundary items; approve/reject requires reason. |
| Model capability dashboard | Matrix by model/profile/skill with promotion state and scores. |
| Audit timeline | Model route, UQLM decision, proof card, validation attempt, operator decision. |

Do not hide proof-card data inside raw JSON. If the operator cannot scan it quickly, the automation has failed its purpose.

### Slice 4 — cc-switch Sensitivity And Capability Routing

Goal: keep routing fast, but only inside measured and allowed capability boundaries.

Status as of 2026-05-25: core router enforcement is implemented in `cc-switch/src-tauri/src/proxy/providers/router.rs`, `cc-switch/src-tauri/src/proxy/handlers.rs`, and `cc-switch/model-router-headless/src/main.rs`. The router can apply promotion-state overrides from DB capability records when those records are present on the pool, and `SupabaseSyncService` has a fetch helper for Portal capability records. The remaining gap is end-to-end wiring/operations: populate real capability records from measured model behavior, feed those records into live routing consistently, and expose the matrix in the UI.

cc-switch changes:

1. Extend model route request with:
   - `data_sensitivity`
   - `validation_action_risk`
   - `proof_ladder_rung`
   - `skill_tag`
   - `required_tags`
   - **Implemented** in both the GUI proxy and headless router.
2. Extend provider/model config with profile and promotion state.
   - **Implemented** with `profile`, `promotion_state`, and `data_sensitivity_allowed` provider fields.
3. Add capability-record lookup keyed by `(model_identifier, profile, skill_tag, data_sensitivity_allowed)`.
   - **Partially implemented**: routing-time capability tags and promotion fields are enforced; DB capability records can override promotion state when loaded into the provider pool; Portal fetch helper exists. Full measured-record ingestion and live routing feed remain Release E work.
4. Filter providers before LocalFirst selection:
   - remove cloud providers when `data_sensitivity=raw_local_only`
   - remove providers without approved/restricted-allowed capability record for the skill
   - remove exploit-capable profiles unless action policy allows them
   - **Implemented** for raw-local-only, promotion state, required tags, and exploit-profile action policy. DB-backed capability-record filtering is partially implemented and still needs end-to-end proof with real measured records.
5. Log why providers were excluded in `candidates_considered`.
   - **Implemented** in route responses from both router endpoints.

Routing invariant:

```text
allowed providers = enabled providers
  filtered by sensitivity
  filtered by model capability record
  filtered by required tags
  filtered by quality floor
then LocalFirst/cost/circuit strategy selects from allowed providers
```

Tests:

- [x] raw local-only never returns cloud.
- [x] shadow model is never selected for execution.
- [x] approved model for report drafting is not automatically approved for exploit validation.
- [x] route response explains exclusions.
- [ ] DB-backed model capability record lookup is populated and proven against real model measurements.

### Slice 5 — Local Redaction Registry And Rehydration

Goal: make cloud-safe reasoning useful without leaking raw evidence.

Status as of 2026-05-25: first Hermes boundary is implemented for analysis findings. The task runner redacts raw finding values before Fabric enrichment, UQLM verification, Portal finding writes, validation-card sync, quarantine child-task creation, receipt reports, and error events. The raw mapping is stored locally only in the redaction registry. The sync worker now fails closed when a queued payload still contains raw private targets or obvious secrets and self-initializes the local SQLite sync schema when `findings.db` exists without required tables. Portal finding creation rejects raw private/secret payloads, finding markdown export fails closed, and report generation is blocked if stored engagement/finding content still contains raw private target or secret material. Remaining work is to formalize `RedactedFindingBrief`, wire operator UI/CLI rehydration, and prove the offline queue drain against the real Supabase schema.

Hermes/local storage changes:

1. Add local redaction registry table/file.
   - **Implemented** as local JSON file via `LocalRedactionRegistry`.
2. Convert raw values to stable refs before cloud model calls or Portal writes.
   - **Implemented for analysis findings** before enrichment, UQLM, Portal writes, proof cards, and quarantine tasks.
3. Store raw mapping locally only.
   - **Implemented**; Portal receives refs, not registry values.
4. Add local rehydration helper for cc-switch/CLI operator view.
   - **Helper implemented**; UI/CLI integration remains pending.
5. Ensure sync worker only sends redacted payloads.
   - **Implemented for raw private IP / obvious secret detection**. Local SQLite schema self-healing is implemented for `sync_queue` and `checkpoint`.

Tests:

- [x] cloud-bound analysis payload contains refs, not raw private domains/IPs/secrets.
- [x] local rehydration restores refs for operator view.
- [x] sync worker rejects queued payloads containing raw private targets or obvious secrets.
- [ ] missing registry routes proof card to review because operator cannot rehydrate.
- [x] Portal finding export cannot send raw private targets or obvious secrets.
- [x] Portal report-generation paths cannot send raw registry values.
- [ ] Prove offline sync queue drain against production-equivalent Supabase schema without missing-table fallbacks.

### Slice 6 — Feedback Loop

Goal: make Hermes improve from reviewed outcomes without self-authorizing.

Implementation:

1. Operator decision updates validation card status.
2. Validation result creates `validation_attempt`.
3. A scoring job updates `model_capability_records` aggregates.
4. Promotion state changes require operator action.
5. cc-switch reads updated records for future route decisions.

Forbidden:

- Hermes may not promote a model by itself.
- Hermes may not relax policy by itself.
- UQLM may not approve execution by itself.
- A model's good report-writing score may not grant exploit-validation trust.

### Slice 7 — End-To-End Proof

End-to-end acceptance scenario:

```text
1. Hermes imports a high-impact finding from enumeration.
2. Hermes redacts sensitive fields and creates a validation card.
3. The proposed proof is read-only and rung 1.
4. The finding is saved as draft with proof card.
5. No quarantine task is created solely because severity is high.
6. Portal proof queue shows the card with expected positive/negative signals.
7. Operator approves or manually validates.
8. The decision updates model capability records.
9. Audit log shows model route -> UQLM -> proof card -> operator decision.
```

Regression scenario:

```text
1. Hermes imports a low-severity finding.
2. The proposed proof includes data extraction or destructive action.
3. Hermes creates a quarantine task.
4. Portal approval queue blocks execution until operator decision.
```

---

## Release Strategy

### Release A — Safe Core (current)
- [x] Foundation schema merged
- [x] Fingerprint standardized
- [x] API routes hardened (8 routes, 11 handlers)
- [x] Hallucination gate Layer 1
- [x] Vuln intel Fabric pattern (`enrich_vuln_intel`)
- [x] Hermes vuln intel adapter (NVD, KEV, EPSS, OSV, retry, circuit breaker, Playwright fallback)
- [x] SQLite schema extended (vuln intel cache + sync_queue + checkpoint)
- [x] Crash checkpoints + offline buffer worker (sync_worker.py + task runner checkpoint logic)
- [x] cc-switch ↔ Hermes + Fabric runtime wiring (Dockerfile, Fabric patterns, report mode, task polling)
- [x] Portal cleaned to dashboard/API boundary (setup wizard removed, model config moved to cc-switch)
- [x] Operator triage with quarantine gates
- [x] cc-switch → Portal model route logging contract — config, selection, usage, and routing audit endpoints exist; route logging writes `model_selections` and `model_routing_results`
- [x] Live Compose proof for Hermes -> cc-switch -> Portal route logging

### Release B — UQLM Integration
- [x] `uqlm_verify.py` adapter module
- [x] UQLM Layer 2 in enrichment gate
- [x] Dockerfile.gateway updated with uqlm + langchain-ollama
- [x] Field-level scorer configuration per engagement
- [x] UQLM confidence in audit_log

### Release C — Advanced Automation
- [x] cc-switch routing foundation — provider pools, circuit breakers, strategy parsing, quality-aware tier selection
- [x] Reconcile model routing ownership — cc-switch is the chooser, Portal is storage/observability
- [x] Align cc-switch model router adapter with Portal `/api/models/route` and normalize response shapes
- [x] Skill manager foundation — cc-switch Skills UI exists; Portal Skills tab remains informational
- [x] Model observability dashboard — ModelDashboard with usage polling
- [x] Tuned UQLM ensemble with ground-truth calibration — uqlm_calibrate.py + calibration weights
- [x] Vuln intel data source caching + local mirror — mirror mode (KEV + NVD pre-fetch)
- [x] End-to-end model-route event proof in the running local stack

### Release D — Sensitive Cloud Assistance
- [x] Define and implement `LocalRedactionRegistry` for stable ref mapping
  - First implementation is local JSON with stable `IP_REF`, `DOMAIN_REF`, and `SECRET_REF` mappings plus rehydration helper.
- [ ] Define `RedactedFindingBrief` as the only cloud-model and Portal-safe finding DTO
- [x] Convert Hermes analysis finding payloads to stable refs before enrichment/UQLM/Portal writes
- [x] Add fail-closed sync-worker guard for raw private targets and obvious secrets
- [x] Add Portal finding create/export boundary checks for raw private targets and obvious secrets
- [x] Add `data_sensitivity` to Hermes -> cc-switch model-route requests
  - Hermes now includes optional `data_sensitivity` and `validation_action_risk` fields when asking cc-switch for a model route. cc-switch enforces the sensitivity boundary before provider selection.
- [x] Enforce `raw_local_only` in cc-switch so cloud providers cannot receive raw sensitive payloads
  - Implemented in the shared Rust router and exercised through the headless router tests.
- [ ] Add local rehydration in cc-switch or CLI for operator-only manual review/testing
  - Core helper exists in Hermes; user-facing operator view is not wired yet.
- [ ] Add Portal write-boundary tests for raw private IPs, domains, URLs, credentials, and PII
- [ ] Add UQLM tests for redacted reproduction templates
- [ ] Prove high-impact finding flow: raw local evidence -> redacted cloud reasoning -> UQLM score -> operator review -> local rehydrated safe test

### Release E — Proof-Driven Automation
- [x] Add canonical enum definitions in Python/Rust/TypeScript/SQL for `data_sensitivity`, `validation_action_risk`, `proof_ladder_rung`, `operator_decision`, and `promotion_state`
  - Implemented as compatibility constants/types in Hermes, Portal TypeScript, Supabase SQL checks, and cc-switch Rust routing policy. Long-term cleanup should move these into generated/shared schema artifacts.
- [x] Add Supabase schema for `validation_cards`, `validation_attempts`, and `model_capability_records`
- [ ] Add local Hermes storage for validation cards, validation attempts, local-only redaction registry, and sync queue payloads
- [ ] Decide whether local PostgreSQL/Supabase-dev is required; if yes, add it to compose using the same canonical schema instead of a parallel schema
- [ ] Add compatibility migration from existing `action_class` / `risk_level` to `validation_action_risk` / `vulnerability_severity`
- [x] Implement proof ladder classification for proposed validation actions
- [x] Update quarantine logic to gate `validation_action_risk`, not only `vulnerability_severity`
- [x] Add Portal APIs for validation cards, validation attempts, and model capability records
- [ ] Add proof-card UI in cc-switch/Portal for quick operator review
- [ ] Add Portal proof queue, approval queue, finding-detail proof panel, model capability dashboard, and audit timeline
- [ ] Add model capability records per `model_identifier` + `skill_tag` + `data_sensitivity`
- [ ] Add shadow-mode evaluation for candidate models
- [ ] Add golden test set for core skills: recon summary, finding enrichment, exploit validation planning, report drafting, UQLM review
- [ ] Add feedback loop from operator decisions into model capability records
- [ ] Prove safe validation flow: high-impact hypothesis -> low-risk proof card -> operator-visible evidence -> no destructive action

---

## Key Risks

| # | Risk | Mitigation |
|---|------|------------|
| R1 | Policy bypass via automation | Default-deny, action-level gating, immutable audit_log |
| R2 | AI hallucination ingested as fact | Layer 1 + 2 gate: Fabric self-report + UQLM verification |
| R3 | Confident hallucination (model certain but wrong) | UQLM semantic entropy + noncontradiction cross-check |
| R4 | Duplicate findings on retry | Canonical fingerprint, UNIQUE constraint, checkpoint resume |
| R5 | Out-of-scope target hit | Scope validation, hard-block from _scope-guard |
| R6 | Internet loss during operation | Local SQLite buffer, async replication |
| R7 | Raw target data leaked to cloud model or Portal | Sensitive Evidence Boundary, `RedactedFindingBrief`, local-only registry, Portal boundary tests |
| R8 | Weak local model misses solution but cloud cannot see raw data | Cloud receives redacted structured brief and produces parameterized strategy; local model/executor rehydrates and validates under scope/approval gates |
| R9 | High-impact finding blocked even when safe proof exists | Separate `vulnerability_severity` from `validation_action_risk`; use proof ladder |
| R10 | Model routing trusts unproven model tags | Capability records, shadow mode, golden tasks, human promotion |
| R11 | Agent self-improvement mutates policy or model trust without review | Feedback may update scores only; policy/model promotion requires operator-reviewed change |
| R12 | Local DB, Supabase, and Portal use different parameter names | Canonical enum contract, compatibility migration, schema/API tests across Python/Rust/TypeScript/SQL |
| R13 | Local PostgreSQL added later with a divergent schema | Treat `schema.sql` as canonical; local Postgres/Supabase-dev must run the same migrations as cloud Supabase |

---

## Reference Docs

| What | Where |
|------|-------|
| Implementation phases (0–12) | `offensive-research-portal/plan.md` |
| Database schema | `offensive-research-portal/supabase/schema.sql` |
| Foundation migrations | `offensive-research-portal/supabase/phase_minus_1_schema.sql` |
| Hallucination gate (Layers 1-2) | `offensive-research-portal/report-viewer/lib/enrichment-gate.ts` |
| Fingerprint formula (Python) | `hermes-agent/scripts/offensive-research-portal-task-runner.py:231` |
| Component contracts | `docs/integrations/` |
| Operational runbooks | `docs/operations/` |
| Stack map & config | `docs/stack-map/` |
| Hermes security skills | `docs/skills/hermes-security/` |
| Pentest methodology (35 agents) | `pentest-ai-agents/.claude/agents/` |
| OMC orchestration (19 agents) | `oh-my-claudecode/agents/` |
| Vuln intel SQLite schema | See Implementation section above |
| NVD API | `nvd.nist.gov/developers/vulnerabilities` |
| CISA KEV catalog | `cisa.gov/known-exploited-vulnerabilities-catalog` |
| EPSS API | `api.first.org/epss/` |
| OSV API | `google.github.io/osv.dev/api/` |
| UQLM library (cloned) | `uqlm/` |
| UQLM scorer definitions | `uqlm/docs/source/scorer_definitions/` |
| UQLM test suite | `uqlm/tests/` |
| Agent development rules | `CLAUDE.md` (Agent Development Rules section) |
| OWASP WSTG testing methodology | `owasp.org/www-project-web-security-testing-guide/` |
| CVE-Bench exploit benchmark | `arxiv.org/abs/2503.17332` |
| CyberGym real-world cyber benchmark | `arxiv.org/abs/2506.02548` |
| AXE agentic exploit validation | `arxiv.org/abs/2602.14345` |
| PoC-Adapt semantic runtime validation | `arxiv.org/abs/2604.06618` |
| Anthropic Project Glasswing / Mythos evidence | `anthropic.com/glasswing`, `red.anthropic.com/2026/cvd/` |
| CI/CD workflows | `offensive-research-portal/.github/workflows/` |
| CODEOWNERS | `offensive-research-portal/.github/CODEOWNERS` |

---

## Development Workflow

Every feature follows this path. CI is the pass/fail authority. No change merges without green checks.

```
Feature branch
  │
  ├─ 1. Write/update tests that prove the behavior
  ├─ 2. Implement the change
  ├─ 3. Run local verification (tests + lint + typecheck + build)
  ├─ 4. Fix everything that fails — do not proceed with red
  │
  ▼
Open pull request → CI runs automatically
  │
  ├─ Gitleaks secret scan
  ├─ Scanner + mapping tests
  ├─ Report-viewer tests + lint + typecheck + build
  ├─ SBOM + audit evidence
  ├─ Preview DAST (security-header scan against Vercel preview)
  │
  ▼
All checks green + human review → merge to develop
  │
  ▼
develop → auto-sync to main → manual deploy to production
```

**Pre-PR verification commands (run these locally before opening a PR):**

```bash
# offensive-research-portal
pnpm test
pnpm --prefix report-viewer lint
pnpm --prefix report-viewer exec vitest run
pnpm --prefix report-viewer exec tsc --noEmit
pnpm --prefix report-viewer build
```

**Agent constraints** (see `CLAUDE.md` Agent Development Rules for full policy):
- Never push to main/develop directly
- Never modify `.github/workflows/` or `CODEOWNERS` without explicit approval
- Never skip hooks
- Never claim success on untested paths
