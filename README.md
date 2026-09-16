# xtm-copilot-skills

Reusable [Copilot skills](https://docs.github.com/copilot) and Docker stacks for an
excellent developer experience when working on the [Filigran XTM suite](https://filigran.io)
with GitHub Copilot.

**The core capability: spawn an isolated instance of the suite — OpenAEV, OpenCTI,
or both together — in minutes, from released Docker Hub images by default or from
a local build.** Each spawned platform comes with its own XTM Composer instance,
ready to deploy and run any connector managed by Composer (an OpenAEV injector or
executor, or an OpenCTI collector/import connector). Testing connectors is one
thing you can do with a spawned suite — not the point of the repo.

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
- **`scripts/`** — thin wrappers around `docker compose` to spawn/tear down one
  platform, or the whole suite, with a single command and sane defaults.

## Quick start

```bash
# Spawn one platform (pulls the released image by default)
./scripts/spawn-openaev.sh up
./scripts/spawn-opencti.sh up

# Or spawn the whole suite (OpenAEV + OpenCTI) with one command
./scripts/spawn-suite.sh up --stack both

# ...and tear it back down
./scripts/spawn-suite.sh down --stack both
```

Pass `--build <path-to-checkout>` (or `--build-openaev` / `--build-opencti` with
`spawn-suite.sh`) to build the image(s) from a local checkout instead of pulling
from Docker Hub — e.g. to test an unreleased platform change.

Every spawn prints the platform's URL and admin credentials once it's healthy.
Each platform is a fully isolated stack (own Docker network/volumes/compose
project name), so OpenAEV and OpenCTI never collide, whether run one at a time or
together via `--stack both`.

## Skills index

| Skill | Use when... |
|---|---|
| [spawn-xtm-suite](.github/skills/spawn-xtm-suite/SKILL.md) | You want to spawn OpenAEV, OpenCTI, or both together, without committing up front to a single platform |
| [spawn-openaev-stack](.github/skills/spawn-openaev-stack/SKILL.md) | You need a local OpenAEV instance running in Docker (from a local build or a released image) |
| [spawn-opencti-stack](.github/skills/spawn-opencti-stack/SKILL.md) | You need a local OpenCTI instance running in Docker |
| [test-connector-with-composer](.github/skills/test-connector-with-composer/SKILL.md) | You need to validate a connector (OpenAEV injector/executor, or OpenCTI collector) end-to-end against a real XTM Composer, including catalog wiring, deployment, and delivery |

## Contributing

This repo is meant to grow: add a new `SKILL.md` whenever you develop a
non-obvious, repeatable procedure while working on the XTM suite with Copilot —
future sessions (yours or teammates') should not have to rediscover the same
gotchas. Keep skills product-agnostic and generalized (no hardcoded PR numbers,
ticket IDs, or one-off paths).
