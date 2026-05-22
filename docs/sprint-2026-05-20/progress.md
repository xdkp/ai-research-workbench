Sprint: 2026-05-20
===================

Summary
-------
- Added `/api/findings/import-from-report` endpoint (requires `reviewed: true`).
- Reports tab action: **Create Draft Finding** (consumes JSON draft reports).
- Added handler tests (3) for the generated-report → draft-finding promotion path.
- Merged foundation schema into `offensive-research-portal/supabase/schema.sql`:
  - `schema_version`, `audit_log`, `approval_policies`
  - `agent_tasks.action_class`, `agent_tasks.approval_reason`
  - finding `fingerprint`, fingerprint trigger/index
- Reconciled model registry: `model_configs` canonical; `model_pool` intentionally unused.
- Updated `rls-service-role.sql`, `phase_minus_1_schema.sql`, rollback notes, plans, and agent contract docs.

Verification
------------
- Typecheck: `pnpm --dir offensive-research-portal/report-viewer exec tsc --noEmit`
- Lint: `pnpm --dir offensive-research-portal/report-viewer lint`
- Tests (focused): `pnpm --dir offensive-research-portal/report-viewer exec vitest run app/api/__tests__/findings-security.test.ts --reporter=verbose`
- Full tests: `pnpm --dir offensive-research-portal/report-viewer test -- --run` → 35 files, 207 tests
- offensive-research-portal package tests: `pnpm --dir offensive-research-portal test`
- Git check: `git diff --check ...`

Phase Status (code-checked)
----------------------------
- Phase 0-5: no local code gaps found.
- Phase 6: operational/observability work ongoing.
- Phase 7-8: no local code gaps found.
- Phase 9-10: substantially complete; report → finding promotion implemented.
- Phase 11: passive Hermes flow + operator-reviewed draft promotion implemented; remaining gap: richer scoped recon/analysis adapters.

Next Steps
----------
- Add tests and coverage for the new `/api/findings/import-from-report` endpoint in CI if not already included.
- Validate Supabase migration in a staging environment (verify fingerprint uniqueness/index behavior).
- Finish operational/observability items in Phase 6.

Notes
-----
This progress note records the work validated locally on 2026-05-20. Push to a branch and open a PR to record history and trigger CI (recommended).
