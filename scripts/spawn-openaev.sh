#!/usr/bin/env bash
# Spawn (or tear down) an isolated OpenAEV Docker stack for local dev/testing.
#
# Usage:
#   scripts/spawn-openaev.sh up [--build <path-to-openaev-checkout>] [-p <project-name>]
#   scripts/spawn-openaev.sh down [-p <project-name>]
#   scripts/spawn-openaev.sh logs [-p <project-name>]
#
# Without --build, pulls the released `openaev/platform:rolling` image (or
# $OPENAEV_IMAGE from stacks/openaev/.env if you copied one).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$SCRIPT_DIR/../stacks/openaev"
PROJECT="openaev-dev"
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
      echo "==> Building OpenAEV image from $BUILD_PATH"
      docker build --tag openaev-dev:latest "$BUILD_PATH"
      export OPENAEV_IMAGE=openaev-dev:latest
    fi
    export COMPOSE_PROJECT_NAME="$PROJECT"
    echo "==> Starting OpenAEV stack (project: $PROJECT)"
    compose up -d
    echo "==> Waiting for OpenAEV to become healthy..."
    for _ in $(seq 1 60); do
      status="$(docker inspect -f '{{.State.Health.Status}}' "${PROJECT}-openaev-1" 2>/dev/null || echo starting)"
      [[ "$status" == "healthy" ]] && break
      sleep 5
    done
    if [[ "$status" != "healthy" ]]; then
      echo "!! OpenAEV did not become healthy in time. Check: docker logs ${PROJECT}-openaev-1" >&2
      echo "!! See the smoke-test-injector-with-composer skill for the fresh-tenant 503 workaround." >&2
      exit 1
    fi
    port="$(grep -E '^OPENAEV_PORT=' "$ENV_FILE" | cut -d= -f2 || echo 8081)"
    admin_email="$(grep -E '^OPENAEV_ADMIN_EMAIL=' "$ENV_FILE" | cut -d= -f2 || echo admin@openaev.io)"
    admin_password="$(grep -E '^OPENAEV_ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2 || echo OpenAEVDevExp2026)"
    echo ""
    echo "OpenAEV is up: http://localhost:${port:-8081}"
    echo "  login:    ${admin_email:-admin@openaev.io}"
    echo "  password: ${admin_password:-OpenAEVDevExp2026}"
    ;;
  down)
    echo "==> Tearing down OpenAEV stack (project: $PROJECT)"
    compose down -v --remove-orphans
    echo "!! Composer-spawned injector containers aren't part of this compose project."
    echo "!! If any are left running, remove them manually: docker ps -a | grep <injector-name>"
    ;;
  logs)
    compose logs -f "${@:-openaev}"
    ;;
  *)
    echo "Usage: $0 {up|down|logs} [--build <path>] [-p <project-name>]" >&2
    exit 1
    ;;
esac
