# Pentest Workbench — Product Architecture

A pentest workbench where **one command bootstraps the full stack** with guided onboarding. **The operator is the decision maker. AI is the research assistant.**

---

## The Team

### cc-switch — Central Management Platform

Your command center. Everything goes through cc-switch. Runs local (Tauri/Rust), no internet required for operation.

- Workflow management — create, edit, approve execution plans before anything runs
- Skill management — browse, add, configure pentest skills, enable/disable
- Model routing — picks the best model per task from your pool, delegates on failure, alerts on limits, circuit-breaks unhealthy providers

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

### Portal — Read-Only Dashboard

Next.js app on Vercel. **Displays data. Never executes. Never holds model or scanner credentials.**

- Views engagements, findings, reports, agent status from Supabase
- Operator triage: confirm/reject findings, review quarantine queue
- "Generate Report" button → creates task → Hermes + Fabric do the work
- Two-layer hallucination gate at API write boundary (`lib/enrichment-gate.ts`)
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
POST /api/findings → enrichment-gate.ts → Supabase → Portal
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
  │
  ▼
UQLM verification (uqlm_verify.py)
  → BlackBoxUQ + LongTextUQ independent scoring
  │
  ▼
POST /api/findings (with vuln_intel + confidence metadata)
  │
  ▼
enrichment-gate.ts
  → Layer 1: Fabric self-reported confidence
  → Layer 2: UQLM independent verification
  │
  ▼
Supabase (draft finding, flagged if uncertain)
  │
  ▼
Portal — operator sees threat intel + confidence profile, triages
```

### UQLM integration point

```
hermes-agent/scripts/
  uqlm_verify.py          ← NEW: wraps UQLM for enrichment verification
  csp-audit-task-runner.py ← MODIFY: calls uqlm_verify after Fabric, before API POST
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
Task assigned → cc-switch matches skill tag to model preferences → routes to best available → circuit-breaks on failure → delegates to next → alerts operator on limits.

### Report generation
Operator clicks "Generate Report" → Portal creates task → Hermes claims → Fabric writes report → Hermes POSTs to Supabase → Portal shows download.

**Portal never writes data directly.** It creates tasks that Hermes picks up. Every piece of data: local executes → writes to Supabase → Portal reads.

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

### Hallucination Defense — Two-Layer Gate

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
3. High/Critical actions require explicit operator approval before execution.
4. Approval is **action-level**, not only finding-level.
5. No background auto-escalation.
6. Model routing failover may NOT bypass approval requirements.
7. Out-of-scope targets are hard-blocked regardless of model recommendation.
8. Policy evaluation failure → default DENY.
9. All approval/rejection decisions are immutable, timestamped, and audited in `audit_log`.

### Action-Level Risk Classification

| Action Class | Examples | Approval Required |
|---|---|---|
| **Passive** | Enumerate, fingerprint, collect headers, DNS lookup | Never |
| **Active non-destructive** | Validation requests, safe probes, version checks | Low/Medium: auto. High/Critical: approve |
| **Active destructive** | Exploit chains, auth bypass, data extraction, payload injection | **Always** |

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

**Gate 2 — Action Quarantine:** Hermes enumerates → classifies next actions → High/Critical OR destructive → QUARANTINED → Hermes stops → Portal shows finding + action + risk class → operator approves/blocks → decision immutable, logged → if approved, Hermes validates.

---

## UQLM Integration Plan

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
| 2 | `hermes-agent/scripts/csp-audit-task-runner.py` | Modify — call uqlm_verify after Fabric, before API POST |
| 3 | `csp-audit/report-viewer/lib/enrichment-gate.ts` | Modify — add Layer 2 UQLM score interpretation |
| 4 | `csp-audit/report-viewer/lib/__tests__/enrichment-gate.test.ts` | Modify — add UQLM Layer 2 test cases |
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
ProviderRouter + CircuitBreaker in Rust. Portal has `model-router.ts` — separate implementation. Skill manager UI not built. Runtime path with Hermes not verified.

### Hermes
Gateway heartbeat + task claim + receipt mode working. Analysis mode with Fabric enrichment, quarantine child-tasks, action classification, and browser validation in `csp-audit-task-runner.py` (745 lines). Vuln intel adapter built (893 lines). Custom Fabric patterns not in Docker image. Fingerprint standardized. UQLM integration not started.

### Fabric
CLI v1.4.452 installed. All 4 custom patterns on disk. Not verified with real findings. Not configured with model API. Patterns not in Docker image.

### UQLM
Library cloned at `uqlm/` (v0.5.11, Apache 2.0). Tests studied — API surface understood. Scorer-to-field mapping done. Integration code not written. Dependencies (langchain, sentence-transformers, etc.) not installed in Hermes container.

### Portal
All 8 targeted routes hardened. Hallucination gate Layer 1 active (18 tests). `createSecureApiHandler` passes route context for dynamic routes. Triage detail panel and evidence workflow not complete.

### Supabase
18 tables, RLS deny-all, service_role bypass. Foundation schema merged into canonical. `model_pool` removed. Fingerprint unified across all systems. Live Supabase needs verification.

### Vuln Intel Pipeline
Schema built (17 tables, v3). `enrich_vuln_intel` Fabric pattern created (139 lines). Hermes vuln intel adapter built (893 lines, `hermes-agent/scripts/vuln_intel_adapter.py`): NVD via CPE/keyword search, CISA KEV full-catalog check, EPSS single + batch lookup, OSV package/version query, Playwright fallback for vendor HTML, SQLite cache read/write, rate limiter per source, circuit breaker (3 failures → 5min open), retry with exponential backoff + Retry-After header respect. Sync worker not created.

### Safety & Resilience
Layer 1 hallucination gate built. Layer 2 UQLM pending. Idempotency built. Crash recovery: schema built (checkpoint table), worker not built. Offline buffer: schema built (sync_queue table), sync worker not built.

Detailed phase tracking: `csp-audit/plan.md` (Phase 0–12)

---

## Release Strategy

### Release A — Safe Core (current)
- [x] Foundation schema merged
- [x] Fingerprint standardized
- [x] API routes hardened (8 routes, 11 handlers)
- [x] Hallucination gate Layer 1
- [x] Vuln intel Fabric pattern (`enrich_vuln_intel`)
- [x] Hermes vuln intel adapter (NVD, KEV, EPSS, OSV, retry, circuit breaker, Playwright fallback)
- [ ] cc-switch ↔ Hermes + Fabric runtime wiring
- [ ] Operator triage with quarantine gates
- [x] SQLite schema extended (vuln intel cache + sync_queue + checkpoint)
- [ ] Crash checkpoints + offline buffer worker

### Release B — UQLM Integration
- [ ] `uqlm_verify.py` adapter module
- [ ] UQLM Layer 2 in enrichment gate
- [ ] Dockerfile.gateway updated with uqlm + langchain-ollama
- [ ] Field-level scorer configuration per engagement
- [ ] UQLM confidence in audit_log

### Release C — Advanced Automation
- [ ] Dynamic model routing with cc-switch
- [ ] Skill manager UI
- [ ] Full observability dashboard
- [ ] Tuned UQLM ensemble with ground-truth calibration
- [ ] Vuln intel data source caching + local mirror

---

## Key Risks

| # | Risk | Mitigation |
|---|------|------------|
| R1 | Policy bypass via automation | Default-deny, action-level gating, immutable audit_log |
| R2 | AI hallucination ingested as fact | Two-layer gate: Fabric self-report + UQLM verification |
| R3 | Confident hallucination (model certain but wrong) | UQLM semantic entropy + noncontradiction cross-check |
| R4 | Duplicate findings on retry | Canonical fingerprint, UNIQUE constraint, checkpoint resume |
| R5 | Out-of-scope target hit | Scope validation, hard-block from _scope-guard |
| R6 | Internet loss during operation | Local SQLite buffer, async replication |

---

## Reference Docs

| What | Where |
|------|-------|
| Implementation phases (0–12) | `csp-audit/plan.md` |
| Database schema | `csp-audit/supabase/schema.sql` |
| Foundation migrations | `csp-audit/supabase/phase_minus_1_schema.sql` |
| Hallucination gate (Layer 1) | `csp-audit/report-viewer/lib/enrichment-gate.ts` |
| Fingerprint formula (Python) | `hermes-agent/scripts/csp-audit-task-runner.py:231` |
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
| CI/CD workflows | `csp-audit/.github/workflows/` |
| CODEOWNERS | `csp-audit/.github/CODEOWNERS` |

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
# csp-audit
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
