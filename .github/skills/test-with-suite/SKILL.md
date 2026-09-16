---
name: test-with-suite
description: >-
  Uses a spawned XTM suite stack (OpenAEV, OpenCTI, or both — see
  spawn-xtm-suite) to test something live: a platform feature/change via its
  UI or API, or a connector (an OpenAEV injector/executor, or an OpenCTI
  collector/import connector) deployed through XTM Composer. Every spawn
  already includes its own XTM Composer instance in one call — Composer just
  isn't the focus unless you're specifically testing a connector through it.
  Use when asked to verify behavior against a real running instance rather
  than just reading code.
---

# Test against a live XTM suite instance

## When to use this

- You want to verify a platform change (backend or frontend, OpenAEV or
  OpenCTI) actually works, by clicking through the UI or hitting the API on a
  real running instance — no connector involved.
- You need to validate a connector end-to-end: catalog/manifest contract,
  Composer deployment, container startup, queue delivery, and actual payload
  processing.
- You're comparing behavior across a PR branch and `main`, or across OpenAEV
  and OpenCTI.

This builds on [spawn-xtm-suite](../spawn-xtm-suite/SKILL.md) (or
[spawn-openaev-stack](../spawn-openaev-stack/SKILL.md) /
[spawn-opencti-stack](../spawn-opencti-stack/SKILL.md) directly), which spin up
an isolated platform + XTM Composer stack (own Docker network, own volumes) —
none of this touches any existing project containers/volumes on the machine.

## Prerequisites

- Docker (or Podman) running locally, with enough resources for the platform(s)
  you're spawning (~6-8GB RAM recommended per platform).
- If testing an unreleased change: the relevant branch checked out locally
  with a buildable Dockerfile (see the individual spawn-*-stack skills for
  `--build` usage).
- For connector testing only: network access to pull the connector's own
  image (referenced by the catalog/connector manifest, e.g.
  `openaev/injector-email-smtp:rolling` or an OpenCTI connector image).

## Procedure

### Step 1 — Spawn the platform(s) you need

```bash
# One platform:
./scripts/spawn-openaev.sh up -p suite-test --build /path/to/openaev-checkout
# or:
./scripts/spawn-opencti.sh up -p suite-test --build /path/to/opencti-checkout

# Both, if you need cross-product behavior or a connector talking to both:
./scripts/spawn-suite.sh up --stack both -p suite-test \
  --build-openaev /path/to/openaev-checkout --build-opencti /path/to/opencti-checkout
```

Omit `--build`/`--build-openaev`/`--build-opencti` to pull the released images
instead. Each script prints the URL + admin credentials once its platform is
healthy. XTM Composer is spawned automatically as part of the stack in this
same call — there's no separate step to start it, even if you don't interact
with it directly. If the spawn times out waiting for health, see the
fresh-tenant 503 gotcha below.

### Step 2 — Testing a platform feature directly (no connector involved)

Log in with the admin credentials printed in Step 1 and exercise the
feature/change via the UI, or hit the platform's REST API directly (Swagger UI
is typically at `/api-docs` for OpenAEV; GraphQL playground at `/graphql` for
OpenCTI). Composer is running in the background but there's nothing to do
with it for this path — you're done once you've confirmed the behavior.

### Step 3 — Testing a connector through Composer

Skip this if you're only testing a platform feature.

**3a. Verify Composer registered:**

```bash
docker logs suite-test-openaev-xtm-composer-1 | grep -i "manager registered"
# and/or:
docker logs suite-test-opencti-xtm-composer-1 | grep -i "manager registered"
```

(Container names follow `<project>-xtm-composer-1`; with `spawn-suite.sh` the
project is `<prefix>-openaev` / `<prefix>-opencti`.) A single early `ERROR ...
Failed to fetch connector instances: status 400` right before `Manager
registered: <uuid>` is a benign startup ordering artifact — ignore it.

**3b. Deploy the connector via the platform's UI/API:**

Enable/deploy the connector from the catalog (OpenAEV) or connector manifest
(OpenCTI), via UI or API. Composer will pull the referenced image and create a
new container.

**Gotcha — wrong Docker network on the spawned container:** Composer-created
connector containers can sometimes land on the default Docker `bridge` network
instead of the compose project's network, breaking hostname resolution
(`Failed to resolve 'openaev'` / `Failed to resolve 'opencti'`). If the
connector container keeps restarting with a `NameResolutionError`, fix it
directly:

```bash
docker network connect <project-name>_default <connector-container-name>
docker restart <connector-container-name>
```

Find the connector container name/id with:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

**3c. Watch the connector's own logs (not just Composer's):**

```bash
docker logs -f <connector-container-name>
```

For an OpenAEV injector/executor, healthy startup looks like:

```
[..._MAIN] ... injector configuration initialized successfully.
Starting PingAlive thread
Starting ListenQueue thread
ListenQueue connecting to RabbitMQ.
```

For an OpenCTI connector, look for it registering successfully and starting
its work loop (exact log format depends on the connector).

**3d. Trigger real work and confirm delivery/processing:**

For an OpenAEV inject: send a test inject from an exercise/scenario using this
injector or executor, then watch the connector's log for it picking up and
processing the message (e.g., for an email-family injector:
`Received email inject message ...` / `Crafting email ... smtp_host=...`).

For an OpenCTI collector/import connector: trigger a run (manually or on its
schedule) and watch its logs for it fetching, transforming, and bundling data,
then confirm the resulting entities/observables appear in OpenCTI.

For email-family injectors specifically, double-check the SMTP host/port
configured on the injector matches the **internal** Docker service+port
(`mailpit:1025`), not the host-published port you might use to browse
Mailpit's web UI (`localhost:8026` / `mailpit:1026` by default in the OpenAEV
stack) — using the host-published port from inside the Docker network causes
`Connection refused`, since it's a host-side mapping only. Confirm delivery in
Mailpit's web UI at `http://localhost:8026` (or whatever `MAILPIT_WEB_PORT` you
set).

## Cleanup

Always tear the stack(s) down when done — they're throwaway infra:

```bash
./scripts/spawn-suite.sh down --stack both -p suite-test
# Composer-spawned connector containers aren't part of the compose project; remove them too:
docker ps -a --format '{{.Names}}' | grep -E '<connector-name-pattern>' | xargs -r docker rm -f
```

If `docker compose down` reports a network is "still in use", it's almost
always because a Composer-spawned connector container is still attached to it
— remove that container first, then retry teardown.

## Known environment gotchas (reference)

| Symptom | Cause | Fix |
|---|---|---|
| `pull access denied for minio/minio` | Old `minio/minio:RELEASE.*` tags delisted from Docker Hub | Already using `pgsty/silo:latest` in both stacks |
| `admin.email should be a valid email address` on startup | `.local`/`.test` TLDs rejected by validator | Use a real-looking TLD, e.g. `admin@openaev.io` / `admin@opencti.io` (already the defaults) |
| OpenAEV `/api/health` returns 503 forever on a fresh stack | No S3 object yet under the tenant's root prefix | `docker exec <project>-minio-1 sh -c "echo -n '' \| mc pipe local/openaev/2cffad3a-0001-4078-b0e2-ef74274022c3/"` |
| Connector container crash-loops with `NameResolutionError` | Composer attached the container to the wrong Docker network | `docker network connect <project>_default <container>` + restart |
| SMTP `Connection refused` from an email injector | Using the host-published Mailpit port instead of its internal port | Use `mailpit:1025` (internal), not `mailpit:1026`/`localhost:1026` (host-published) |
