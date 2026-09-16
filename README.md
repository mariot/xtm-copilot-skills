# xtm-copilot-skills

Reusable [Copilot skills](https://docs.github.com/copilot) and Docker stacks for an
excellent developer experience when working on the [Filigran XTM suite](https://filigran.io)
(OpenAEV, OpenCTI, XTM Composer, XTM One, and their injectors/connectors) with
GitHub Copilot.

## What's in here

- **`.github/skills/`** — Copilot skill definitions (`SKILL.md`, following the same
  frontmatter + procedure format used across Filigran's product repos). Copilot
  automatically discovers and can invoke these when a matching task comes up in a
  session that has this repo checked out or linked.
- **`stacks/`** — throwaway, isolated Docker Compose stacks to spin up a full
  product locally in minutes:
  - [`stacks/openaev/`](stacks/openaev) — OpenAEV (Postgres, Silo/MinIO, RabbitMQ,
    Elasticsearch, Mailpit, XTM Composer).
  - [`stacks/opencti/`](stacks/opencti) — OpenCTI (Redis, Elasticsearch, Silo/MinIO,
    RabbitMQ, worker, XTM Composer), adapted from the
    [official OpenCTI docker-compose template](https://github.com/OpenCTI-Platform/docker).
- **`scripts/`** — thin wrappers around `docker compose` to spawn/tear down each
  stack with a single command and sane defaults.

## Quick start

```bash
# Spawn OpenAEV (builds the image from a local checkout, or pulls `openaev/platform:rolling`)
./scripts/spawn-openaev.sh up
./scripts/spawn-openaev.sh down

# Spawn OpenCTI
./scripts/spawn-opencti.sh up
./scripts/spawn-opencti.sh down
```

Both scripts print the URL and admin credentials once the stack is healthy. Each
stack is fully isolated (own Docker network/volumes/compose project name), so you
can run OpenAEV and OpenCTI side by side, or several instances at once with
different project names.

## Skills index

| Skill | Use when... |
|---|---|
| [spawn-openaev-stack](.github/skills/spawn-openaev-stack/SKILL.md) | You need a local OpenAEV instance running in Docker (from a local build or a released image) |
| [spawn-opencti-stack](.github/skills/spawn-opencti-stack/SKILL.md) | You need a local OpenCTI instance running in Docker |
| [smoke-test-injector-with-composer](.github/skills/smoke-test-injector-with-composer/SKILL.md) | You need to validate an OpenAEV injector end-to-end against a real XTM Composer, including catalog wiring, deployment, and inject delivery |

## Contributing

This repo is meant to grow: add a new `SKILL.md` whenever you develop a
non-obvious, repeatable procedure while working on XTM products with Copilot —
future sessions (yours or teammates') should not have to rediscover the same
gotchas. Keep skills product-agnostic and generalized (no hardcoded PR numbers,
ticket IDs, or one-off paths).
