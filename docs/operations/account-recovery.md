
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
```

Check:

```text
Vercel project root = csp-audit/report-viewer
build command
install command
environment variables
custom domains
GitHub repo connection
```

Do not change code just because the Vercel account changed unless project IDs or URLs are hardcoded in docs/config.

## Supabase

What breaks:

- Scan history.
- Agent tasks.
- Findings/evidence/report storage.

Recreate/update:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
schema from csp-audit/supabase/schema.sql
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

Only add secrets that the workflow actually needs.

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
