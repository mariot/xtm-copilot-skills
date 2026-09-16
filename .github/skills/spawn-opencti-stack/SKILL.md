---
name: spawn-opencti-stack
description: >-
  Spins up an isolated OpenCTI Docker Compose stack (Redis, Elasticsearch, Silo/MinIO,
  RabbitMQ, worker, XTM Composer) from released images, and reports the URL + admin
  credentials once healthy. Use when asked to run/test OpenCTI locally, verify a
  connector, or test XTM Composer/OpenAEV interoperability against a real OpenCTI.
---

# Spawn an OpenCTI Docker stack

## When to use this

- You need a real, running OpenCTI instance to click through, hit its API, or test
  a connector end-to-end.
- You're testing XTM Composer or cross-product behavior (e.g. OpenAEV ↔ OpenCTI)
  and need both platforms up at once — spawn this alongside
  [spawn-openaev-stack](../spawn-openaev-stack/SKILL.md) with distinct project
  names so their Docker networks/volumes don't collide.

This repo's `stacks/opencti/compose.yml` is adapted from the
[official OpenCTI docker-compose template](https://github.com/OpenCTI-Platform/docker),
trimmed to the platform + worker + XTM Composer (no built-in export/import
connectors, no XTM One) to keep the stack lean for local dev/testing. It's
throwaway and isolated — its own Docker network + named volumes, scoped to a
compose project name.

## Procedure

```bash
./scripts/spawn-opencti.sh up
```

Pulls `opencti/platform:rolling` and `opencti/worker:rolling` (or
`$OPENCTI_IMAGE` / `$OPENCTI_WORKER_IMAGE` from `stacks/opencti/.env` if you've
copied `.env.sample` and set them — e.g. to point at a locally built image).

OpenCTI's first boot (index bootstrap, migrations) is slower than OpenAEV's —
expect a few minutes before the health check passes.

### Multiple stacks at once

```bash
./scripts/spawn-opencti.sh up -p opencti-pr
```

### Watching logs / cleanup

```bash
./scripts/spawn-opencti.sh logs            # follows the opencti service
./scripts/spawn-opencti.sh logs worker
./scripts/spawn-opencti.sh down            # tears the stack down (volumes included)
```

## Once it's up

The script prints the URL and admin login/password. To test a connector,
deploy it via XTM Composer against this instance the same way you would for
OpenAEV — see
[smoke-test-injector-with-composer](../smoke-test-injector-with-composer/SKILL.md)
for the general Composer walkthrough and Docker-networking gotchas (the same
network-attachment issue applies to connectors deployed against OpenCTI).

## Known environment gotchas (reference)

| Symptom | Cause | Fix |
|---|---|---|
| `pull access denied for minio/minio` | Old `minio/minio:RELEASE.*` tags delisted from Docker Hub | Already using `pgsty/silo:latest` in this stack |
| OpenCTI takes a long time to report healthy | Elasticsearch index bootstrap + platform migrations on first boot | Normal — give it several minutes; watch `docker logs <project>-opencti-1` |
| Connector container crash-loops with `NameResolutionError` for `opencti` | Composer attached the container to the wrong Docker network | `docker network connect <project>_default <container>` + `docker restart <container>` |
