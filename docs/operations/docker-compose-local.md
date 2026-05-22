# Docker Compose Local Services

This workspace keeps Compose limited to repeatable background services. The first service group is `offensive-research-portal` report-viewer plus scan worker, and Hermes gateway now seeds its runtime credentials into the Hermes home volume before starting.

## Current Scope

- `offensive-research-portal`: builds and runs the Next.js report viewer locally.
- `csp-scan-worker`: polls for queued scans and executes them locally.
- `hermes-gateway`: runs the Hermes messaging gateway with Hermes-owned runtime config and a background offensive-research-portal heartbeat bridge.

## Files

- `docker-compose.yml`
- `docker-compose.env.example`
- `offensive-research-portal/report-viewer/Dockerfile`
- `offensive-research-portal/report-viewer/.dockerignore`
- `offensive-research-portal/Dockerfile.worker`
- `offensive-research-portal/.dockerignore`
- `offensive-research-portal/scripts/scan-worker.sh`
- `hermes-agent/Dockerfile.gateway`
- `hermes-agent/.dockerignore`

## How To Run

1. Copy the example env file.

```bash
cp docker-compose.env.example docker-compose.env
```

2. Fill in the required values for your local setup.

3. Start the service group.

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal up --build
```

4. Open the viewer at `http://127.0.0.1:3000`.

5. The scan worker runs in the same profile and polls the viewer API over the internal Compose network.

6. Start the Hermes gateway profile when Hermes bot config is ready.

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway up --build
```

7. Hermes gateway keeps its own runtime state in the `hermes-home` volume and writes managed credentials into `hermes-home/.env`.

8. The gateway also sends a lightweight heartbeat to the offensive-research-portal Agent API so the portal can see Hermes as an active agent.

## Notes

- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are required for the API routes that read or write report data.
- `SCAN_WORKER_TOKEN` and `AGENT_TOKEN` are only needed if you exercise the worker and agent API routes.
- `SCAN_WORKER_IDLE_SECONDS` controls how long the worker sleeps between poll cycles.
- Hermes gateway seeds `AGENT_TOKEN`, bot tokens, and offensive-research-portal agent identity fields into `hermes-home/.env` on startup.
- Viewer auth remains optional for local use.
- Hermes gateway config stays under Hermes ownership and is isolated from `offensive-research-portal` state.
- Kubernetes is still out of scope.
