
# Account Recovery

Use this when an external account is lost, replaced, or moved.

The usual fix is to replace secrets and project IDs, not to change application code.

## Vercel

What breaks:

- Preview/prod deploys.
- Preview DAST.
- Hosted report-viewer if the old project is gone.
- Custom domains attached to old account.

Recreate/update:

```text
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
VERCEL_AUTOMATION_BYPASS_SECRET, if preview DAST is used
REPORT_VIEWER_BASE_URL as a GitHub Actions repository variable after first deploy
```

New-account setup checklist:

```text
Create or link Vercel project under the new account
Connect GitHub repo: xdkp/offensive-research-portal
Set project root directory: report-viewer
Use Next.js framework defaults
Set production branch: main
Keep GitHub Actions as production deploy controller
Disable Vercel Git production auto-deploys until intentionally enabled
```

Vercel environment variables to recreate:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_REQUEST_TIMEOUT_MS
SCAN_WORKER_TOKEN
AGENT_TOKEN
VIEWER_BASIC_AUTH_USER
VIEWER_BASIC_AUTH_PASSWORD
VIEWER_SESSION_SECRET
VERCEL_AUTOMATION_BYPASS_SECRET
```

Do not change application code just because the Vercel account changed. Only update hardcoded old URLs, account IDs, project IDs, and deployment docs/config.

## Supabase

What breaks:

- Scan history.
- Agent tasks.
- Findings/evidence/report storage.

Recreate/update:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
schema from offensive-research-portal/supabase/schema.sql
```

Run schema before using the portal.

## GitHub

What breaks:

- CI secrets.
- GitHub Actions deploys/scans.
- PR checks.

Recreate/update repository secrets:

```text
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
VERCEL_AUTOMATION_BYPASS_SECRET
SCAN_WORKER_TOKEN
AGENT_TOKEN
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

Only add secrets that the workflow actually needs. Add non-secret `REPORT_VIEWER_BASE_URL` as a repository variable, not a secret, unless you intentionally keep the hosted URL private.

## Model Provider

What breaks:

- Hermes model calls.
- Codex/Claude Code profile calls.
- Fabric pattern calls, if configured for that provider.

Recovery:

1. Rotate old provider key if possibly exposed.
2. Update the owner config: cc-switch profile or Hermes config.
3. Test one minimal prompt.
4. Update duplicated keys only if documented.

## Bot Accounts

What breaks:

- Hermes gateway delivery.
- Slack/Telegram/Discord callbacks.

Recovery:

1. Create replacement bot/app.
2. Update Hermes gateway secrets.
3. Update webhooks or callback URLs.
4. Restart gateway.
5. Send a test message.
