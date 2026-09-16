---
name: smoke-test-injector-with-composer
description: >-
  Uses the OpenAEV stack in this repo plus XTM Composer to smoke-test an injector
  end-to-end (catalog contract → Composer deploy → container startup → RabbitMQ inject
  → actual payload delivery). Use when asked to test a PR that adds/changes an injector
  by actually running it, or to verify a catalog entry is correctly wired at runtime.
---

# Smoke-test an injector with XTM Composer

## When to use this

- A PR adds or changes an entry in `openaev-api/src/main/resources/resources/catalog/catalog-integrators.json`
  (or any other injector catalog file) and you want proof it works at runtime, not just
  that the JSON is valid.
- You need to verify Composer can pull the injector image, deploy it, and that it
  registers with OpenAEV and processes an inject from RabbitMQ.

This builds on [spawn-openaev-stack](../spawn-openaev-stack/SKILL.md), which already
wires up an isolated OpenAEV + XTM Composer stack (own Docker network, own volumes) —
it does not touch any existing project containers/volumes on the machine.

## Prerequisites

- Docker (or Podman) running locally, with enough resources for Postgres + Elasticsearch +
  RabbitMQ + OpenAEV + Composer (~6-8GB RAM recommended).
- The PR branch checked out locally with a buildable `Dockerfile` at the repo root
  (frontend must already be built — `openaev-front/builder/prod/build/` — or run
  `yarn build` first if the Dockerfile's multi-stage build doesn't do it for you).
- Network access to pull base images and the injector image referenced in the
  catalog entry's `catalog_connector_container_image` (e.g.
  `openaev/injector-email-smtp:rolling`).

## Procedure

### Step 1 — Spawn the stack from the PR checkout

```bash
../xtm-copilot-skills/scripts/spawn-openaev.sh up --build /path/to/pr-checkout -p smoke-test
```

(Adjust the relative path to wherever you cloned `xtm-copilot-skills`.) This
builds the image from the checkout, starts Postgres/Silo/RabbitMQ/Elasticsearch/
Mailpit/OpenAEV/XTM Composer, waits for OpenAEV to report healthy, and prints the
URL + admin credentials.

If it times out waiting for health, see the fresh-tenant 503 gotcha below.

### Step 2 — Verify Composer registered

```bash
docker logs smoke-test-xtm-composer-1 | grep -i "manager registered"
```

A single early `ERROR ... Failed to fetch connector instances: status 400` right
before `Manager registered: <uuid>` is a benign startup ordering artifact — ignore it.

### Step 3 — Deploy the injector via the OpenAEV UI/API

Log in with the admin credentials printed by Step 1, then enable/deploy the
injector connector from the catalog (via UI or API). Composer will pull the
image referenced by the catalog entry's `catalog_connector_container_image` and
create a new container.

**Gotcha — wrong Docker network on the spawned container:** Composer-created
injector containers can sometimes land on the default Docker `bridge` network
instead of the compose project's network, breaking hostname resolution
(`Failed to resolve 'openaev'`). If the injector container keeps restarting with a
`NameResolutionError`, fix it directly:

```bash
docker network connect smoke-test_default <injector-container-name>
docker restart <injector-container-name>
```

Find the injector container name/id with:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

### Step 4 — Watch the injector's own logs (not just Composer's)

```bash
docker logs -f <injector-container-name>
```

Healthy startup looks like:

```
[..._MAIN] ... injector configuration initialized successfully.
Starting PingAlive thread
Starting ListenQueue thread
ListenQueue connecting to RabbitMQ.
```

### Step 5 — Trigger a real inject and confirm delivery

Send a test inject/payload from an exercise or scenario using this injector, then
watch the same injector log for:

```
Received email inject message ...
Crafting email ... smtp_host=..., smtp_port=...
```

For email-family injectors, double-check the SMTP host/port configured on the
injector matches the **internal** Docker service+port (`mailpit:1025`), not the
host-published port you might use to browse Mailpit's web UI (`localhost:8026` /
`mailpit:1026` by default in this stack) — using the host-published port from
inside the Docker network causes `Connection refused`, since it's a host-side
mapping only.

Confirm delivery in Mailpit's web UI at `http://localhost:8026` (or whatever
`MAILPIT_WEB_PORT` you set).

## Cleanup

Always tear the stack down when done — it's throwaway infra:

```bash
../xtm-copilot-skills/scripts/spawn-openaev.sh down -p smoke-test
# Composer-spawned injector containers aren't part of the compose project; remove them too:
docker ps -a --format '{{.Names}}' | grep -E '<injector-name-pattern>' | xargs -r docker rm -f
```

If `docker compose down` reports the network is "still in use", it's almost
always because a Composer-spawned injector container is still attached to it —
remove that container first, then retry teardown.

## Known environment gotchas (reference)

| Symptom | Cause | Fix |
|---|---|---|
| `pull access denied for minio/minio` | Old `minio/minio:RELEASE.*` tags delisted from Docker Hub | Already using `pgsty/silo:latest` in this stack |
| `admin.email should be a valid email address` on startup | `.local`/`.test` TLDs rejected by validator | Use a real-looking TLD, e.g. `admin@openaev.io` (already the default) |
| `/api/health` returns 503 forever on a fresh stack | No S3 object yet under the tenant's root prefix | `docker exec smoke-test-minio-1 sh -c "echo -n '' \| mc pipe local/openaev/2cffad3a-0001-4078-b0e2-ef74274022c3/"` |
| Injector container crash-loops with `NameResolutionError` for `openaev` | Composer attached the container to the wrong Docker network | `docker network connect smoke-test_default <container>` + restart |
| SMTP `Connection refused` from an email injector | Using the host-published Mailpit port instead of its internal port | Use `mailpit:1025` (internal), not `mailpit:1026`/`localhost:1026` (host-published) |
