---
name: spawn-openaev-stack
description: >-
  Spins up an isolated OpenAEV Docker Compose stack (Postgres, Silo/MinIO, RabbitMQ,
  Elasticsearch, Mailpit, XTM Composer) either from a released image or built from a
  local checkout, and reports the URL + admin credentials once healthy. Use when asked
  to run/test OpenAEV locally, verify a change against a live instance, or test a
  connector (injector, executor) end-to-end.
---

# Spawn an OpenAEV Docker stack

## When to use this

- You need a real, running OpenAEV instance to click through, hit its API, or test
  a connector (injector/executor) end-to-end — not just to read code.
- You need OpenAEV as one half of the full XTM suite — see
  [spawn-xtm-suite](../spawn-xtm-suite/SKILL.md) to spawn it alongside OpenCTI.
- A PR changes backend or frontend behavior and you want to verify it live before
  it's reviewed/merged.

This repo's `stacks/openaev/compose.yml` stack is throwaway and isolated (its own
Docker network + named volumes, scoped to a compose project name) — it never
touches other projects' containers on the machine.

## Procedure

### Option A — released image (fastest)

```bash
./scripts/spawn-openaev.sh up
```

Pulls `openaev/platform:rolling` (or `$OPENAEV_IMAGE` from `stacks/openaev/.env`
if you've copied `.env.sample` and set one) and starts the full stack.

### Option B — build from a local checkout (to test unreleased changes)

```bash
./scripts/spawn-openaev.sh up --build /path/to/openaev-checkout
```

This runs `docker build` from that checkout's root first (the frontend must
already be built there — check `openaev-front/builder/prod/build/` or run
`yarn build` beforehand if the Dockerfile doesn't do it for you), then starts the
stack with that image.

### Multiple stacks at once

Pass `-p <project-name>` to run several isolated stacks side by side (e.g. to
compare a PR branch against `main`):

```bash
./scripts/spawn-openaev.sh up --build /path/to/pr-checkout -p openaev-pr
./scripts/spawn-openaev.sh up -p openaev-main
```

### Watching logs / cleanup

```bash
./scripts/spawn-openaev.sh logs            # follows the openaev service
./scripts/spawn-openaev.sh logs rabbitmq   # or any other service name
./scripts/spawn-openaev.sh down            # tears the stack down (volumes included)
```

## Once it's up

The script prints the URL and admin login/password. To also test a connector
against a real XTM Composer, deploy one from the OpenAEV catalog UI — see the
[test-with-suite](../test-with-suite/SKILL.md)
skill for the full walkthrough and its Docker-networking gotchas.

## Known environment gotchas (reference)

| Symptom | Cause | Fix |
|---|---|---|
| `pull access denied for minio/minio` | Old `minio/minio:RELEASE.*` tags delisted from Docker Hub | Already using `pgsty/silo:latest` in this stack — if you see this, check for a stale image reference |
| `admin.email should be a valid email address` on startup | `.local`/`.test` TLDs rejected by validator | Use a real-looking TLD, e.g. `admin@openaev.io` (already the default) |
| `/api/health` returns 503 forever on a fresh stack | No S3 object yet under the tenant's root prefix | `docker exec <project>-minio-1 sh -c "echo -n '' \| mc pipe local/openaev/2cffad3a-0001-4078-b0e2-ef74274022c3/"` |
| Connector container crash-loops with `NameResolutionError` for `openaev` | Composer attached the container to the wrong Docker network | `docker network connect <project>_default <container>` + `docker restart <container>` |
