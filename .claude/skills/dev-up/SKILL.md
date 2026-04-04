---
name: dev-up
description: "Start the full [PROJECT_NAME] dev environment."
disable-model-invocation: true
---

# Dev Up

Start the full development environment with one command.

<!-- CUSTOMIZE: Replace the commands below with your project's dev startup sequence.
     Examples:
     - Elixir: docker compose up (Phoenix on :4000)
     - Node: docker compose up (Next.js on :3000)
     - Python: docker compose up (Django on :8000)
     - If you have companion processes (e.g., host-side helpers), add them here. -->

## What It Starts

1. **Docker compose** (`docker compose up`) — app server
   <!-- CUSTOMIZE: Add any companion processes your project needs -->

## Execution

```bash
docker compose up
```

## Health Check

After starting, verify:
<!-- CUSTOMIZE: Add health check commands for your stack -->
1. `curl -s -o /dev/null -w "%{http_code}" http://localhost:[PORT]` returns `200`

If it fails, report the issue.

## Teardown

To stop: `Ctrl+C` on docker compose.
