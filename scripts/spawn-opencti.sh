#!/usr/bin/env bash
# Spawn (or tear down) an isolated OpenCTI Docker stack for local dev/testing.
#
# Usage:
#   scripts/spawn-opencti.sh up [--build <path-to-opencti-checkout>] [-p <project-name>]
#   scripts/spawn-opencti.sh down [-p <project-name>]
#   scripts/spawn-opencti.sh logs [-p <project-name>]
#
# Without --build, pulls the released `opencti/platform:rolling` /
# `opencti/worker:rolling` images (or $OPENCTI_IMAGE / $OPENCTI_WORKER_IMAGE
# from stacks/opencti/.env if you copied one).
#
# With --build <path>, builds both images from an OpenCTI monorepo checkout at
# <path> (expects the standard `opencti-platform/` and `opencti-worker/`
# top-level folders, each with their own Dockerfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$SCRIPT_DIR/../stacks/opencti"
PROJECT="opencti-dev"
ACTION="${1:-}"
shift || true

BUILD_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD_PATH="$2"; shift 2 ;;
    -p|--project) PROJECT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

ENV_FILE="$STACK_DIR/.env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$STACK_DIR/.env.sample"

compose() {
  docker compose -p "$PROJECT" --env-file "$ENV_FILE" -f "$STACK_DIR/compose.yml" "$@"
}

case "$ACTION" in
  up)
    if [[ -n "$BUILD_PATH" ]]; then
      echo "==> Building OpenCTI platform image from $BUILD_PATH/opencti-platform"
      docker build --tag opencti-dev:latest "$BUILD_PATH/opencti-platform"
      echo "==> Building OpenCTI worker image from $BUILD_PATH/opencti-worker"
      docker build --tag opencti-worker-dev:latest "$BUILD_PATH/opencti-worker"
      export OPENCTI_IMAGE=opencti-dev:latest
      export OPENCTI_WORKER_IMAGE=opencti-worker-dev:latest
    fi
    export COMPOSE_PROJECT_NAME="$PROJECT"
    echo "==> Starting OpenCTI stack (project: $PROJECT)"
    compose up -d
    echo "==> Waiting for OpenCTI to become healthy (this can take a few minutes)..."
    for _ in $(seq 1 90); do
      status="$(docker inspect -f '{{.State.Health.Status}}' "${PROJECT}-opencti-1" 2>/dev/null || echo starting)"
      [[ "$status" == "healthy" ]] && break
      sleep 5
    done
    if [[ "$status" != "healthy" ]]; then
      echo "!! OpenCTI did not become healthy in time. Check: docker logs ${PROJECT}-opencti-1" >&2
      exit 1
    fi
    port="$(grep -E '^OPENCTI_PORT=' "$ENV_FILE" | cut -d= -f2 || echo 8080)"
    admin_email="$(grep -E '^OPENCTI_ADMIN_EMAIL=' "$ENV_FILE" | cut -d= -f2 || echo admin@opencti.io)"
    admin_password="$(grep -E '^OPENCTI_ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2 || echo OpenCTIDevExp2026)"
    echo ""
    echo "OpenCTI is up: http://localhost:${port:-8080}"
    echo "  login:    ${admin_email:-admin@opencti.io}"
    echo "  password: ${admin_password:-OpenCTIDevExp2026}"
    ;;
  down)
    echo "==> Tearing down OpenCTI stack (project: $PROJECT)"
    compose down -v --remove-orphans
    echo "!! Composer-spawned connector containers aren't part of this compose project."
    echo "!! If any are left running, remove them manually: docker ps -a | grep <connector-name>"
    ;;
  logs)
    compose logs -f "${@:-opencti}"
    ;;
  *)
    echo "Usage: $0 {up|down|logs} [--build <path>] [-p <project-name>]" >&2
    exit 1
    ;;
esac
