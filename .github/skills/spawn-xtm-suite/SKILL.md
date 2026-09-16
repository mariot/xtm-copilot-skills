---
name: spawn-xtm-suite
description: >-
  Spins up any combination of the XTM suite — OpenAEV, OpenCTI, or both —
  each as its own isolated Docker Compose stack with its own XTM Composer
  instance, from released images or a local build. Use when asked to test the
  suite end-to-end, run OpenAEV and OpenCTI together, or when the specific
  platform isn't yet decided.
---

# Spawn the XTM suite (OpenAEV, OpenCTI, or both)

## When to use this

- You want a running instance of the suite to test against — a connector
  (injector, collector, or executor), cross-product behavior, or just to click
  through a live deployment — without deciding up front which single platform
  you need.
- You need OpenAEV and OpenCTI running side by side (e.g. testing a connector
  that talks to both, or comparing behavior across products).

This is a thin wrapper around
[spawn-openaev-stack](../spawn-openaev-stack/SKILL.md) and
[spawn-opencti-stack](../spawn-opencti-stack/SKILL.md) — use those directly
(via `scripts/spawn-openaev.sh` / `scripts/spawn-opencti.sh`) if you only ever
need one platform. `scripts/spawn-suite.sh` exists purely to spawn/tear down
either or both together under one shared prefix, without you having to
remember two separate project names.

## Procedure

### Pick your stack(s)

```bash
# OpenAEV only:
./scripts/spawn-suite.sh up --stack openaev

# OpenCTI only:
./scripts/spawn-suite.sh up --stack opencti

# Both, side by side:
./scripts/spawn-suite.sh up --stack both
```

Each platform becomes its own isolated compose project
(`xtm-dev-openaev` / `xtm-dev-opencti` by default), each with its own Docker
network, volumes, and XTM Composer instance — the two stacks never collide,
and each Composer manages connectors for its own platform only.

Add `-p <prefix>` to change the shared prefix (useful for running multiple
suites side by side, e.g. to compare a PR branch against `main`):

```bash
./scripts/spawn-suite.sh up --stack both -p suite-pr
```

### Build from local checkouts instead of pulling released images

```bash
./scripts/spawn-suite.sh up --stack both \
  --build-openaev /path/to/openaev-checkout \
  --build-opencti /path/to/opencti-checkout
```

You can mix released + local — e.g. only `--build-openaev` to test an OpenAEV
change against a released OpenCTI.

### Watching logs / cleanup

```bash
./scripts/spawn-suite.sh logs --stack openaev            # --stack both is ambiguous for logs; pick one
./scripts/spawn-suite.sh down --stack both -p xtm-dev
```

## Once it's up

Each spawned stack prints its own URL and admin login/password (openaev.io /
opencti.io email domains by default). From there, deploy and test a connector
against either platform — see
[test-with-suite](../test-with-suite/SKILL.md) for
the full connector-testing walkthrough, including Docker-networking gotchas
that apply to both platforms.
