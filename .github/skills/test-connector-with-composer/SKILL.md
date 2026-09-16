---
name: test-connector-with-composer
description: >-
  Uses the XTM suite stacks in this repo (OpenAEV, OpenCTI, or both) plus XTM
  Composer to test a connector end-to-end — an OpenAEV injector, an OpenCTI
  collector/import connector, or an executor — across catalog contract,
  Composer deployment, container startup, queue delivery, and actual payload
  processing. Use when asked to test a connector by actually running it, or to
  verify a catalog entry is correctly wired at runtime.
---

# Test a connector with XTM Composer

## When to use this

- A PR adds or changes a connector's catalog contract (e.g.
  `openaev-api/src/main/resources/resources/catalog/catalog-integrators.json`
  for OpenAEV injectors/executors, or an OpenCTI connector manifest) and you
  want proof it works at runtime, not just that the contract is valid.
- You need to verify Composer can pull the connector's image, deploy it, and
  that it registers with the platform and processes work from the queue
  (RabbitMQ for OpenAEV injects, or the OpenCTI connector protocol).
- The connector talks to both platforms (e.g. an OpenAEV injector that also
  reads from OpenCTI, or vice versa) — spawn both with
  [spawn-xtm-suite](../spawn-xtm-suite/SKILL.md) first.

This builds on [spawn-openaev-stack](../spawn-openaev-stack/SKILL.md) and/or
[spawn-opencti-stack](../spawn-opencti-stack/SKILL.md) (or
[spawn-xtm-suite](../spawn-xtm-suite/SKILL.md) for both at once), which already
wire up an isolated platform + XTM Composer stack (own Docker network, own
volumes) — none of this touches any existing project containers/volumes on
the machine.

## Prerequisites

- Docker (or Podman) running locally, with enough resources for the platform(s)
  you're spawning (~6-8GB RAM recommended per platform).
- If testing an unreleased connector or platform change: the relevant branch
  checked out locally with a buildable Dockerfile (see the individual
  spawn-*-stack skills for `--build` usage).
- Network access to pull base images and the connector's own image (referenced
  by the catalog/connector manifest, e.g.
  `openaev/injector-email-smtp:rolling` or an OpenCTI connector image).

## Procedure

### Step 1 — Spawn the platform(s) you need

```bash
# One platform:
./scripts/spawn-openaev.sh up -p test-connector --build /path/to/openaev-checkout
# or:
./scripts/spawn-opencti.sh up -p test-connector --build /path/to/opencti-checkout

# Both, if the connector talks to both platforms:
./scripts/spawn-suite.sh up --stack both -p test-connector \
  --build-openaev /path/to/openaev-checkout --build-opencti /path/to/opencti-checkout
```

Omit `--build`/`--build-openaev`/`--build-opencti` to pull the released images
instead. Each script prints the URL + admin credentials once its platform is
healthy. If it times out waiting for health, see the fresh-tenant 503 gotcha
below.

### Step 2 — Verify Composer registered

```bash
docker logs test-connector-openaev-xtm-composer-1 | grep -i "manager registered"
# and/or:
docker logs test-connector-opencti-xtm-composer-1 | grep -i "manager registered"
```

(Container names follow `<project>-xtm-composer-1`; with `spawn-suite.sh` the
project is `<prefix>-openaev` / `<prefix>-opencti`.) A single early `ERROR ...
Failed to fetch connector instances: status 400` right before `Manager
registered: <uuid>` is a benign startup ordering artifact — ignore it.

### Step 3 — Deploy the connector via the platform's UI/API

Log in with the admin credentials printed in Step 1, then enable/deploy the
connector from the catalog (OpenAEV) or connector manifest (OpenCTI), via UI
or API. Composer will pull the referenced image and create a new container.

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

### Step 4 — Watch the connector's own logs (not just Composer's)

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

### Step 5 — Trigger real work and confirm delivery/processing

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
./scripts/spawn-suite.sh down --stack both -p test-connector
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
