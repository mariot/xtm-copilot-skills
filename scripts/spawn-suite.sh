#!/usr/bin/env bash
# Spawn (or tear down) any part of the XTM suite — OpenAEV, OpenCTI, or both —
# in one command, so you can test a connector (injector, collector, or
# executor) via XTM Composer against a real, isolated platform instance.
#
# Usage:
#   scripts/spawn-suite.sh up --stack openaev|opencti|both \
#       [--build-openaev <path>] [--build-opencti <path>] [-p <prefix>]
#   scripts/spawn-suite.sh down --stack openaev|opencti|both [-p <prefix>]
#   scripts/spawn-suite.sh logs --stack openaev|opencti [-p <prefix>] [service]
#
# Each platform is spun up as its own isolated compose project named
# "<prefix>-openaev" / "<prefix>-opencti" (default prefix: xtm-dev), so running
# --stack both gives you two independent stacks side by side — each with its
# own XTM Composer instance managing its own connectors. This is a thin
# wrapper around spawn-openaev.sh / spawn-opencti.sh; use those directly if you
# only ever need one platform.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-}"
shift || true

STACK="both"
PREFIX="xtm-dev"
BUILD_OPENAEV=""
BUILD_OPENCTI=""
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    -p|--prefix) PREFIX="$2"; shift 2 ;;
    --build-openaev) BUILD_OPENAEV="$2"; shift 2 ;;
    --build-opencti) BUILD_OPENCTI="$2"; shift 2 ;;
    *) EXTRA+=("$1"); shift ;;
  esac
done

run_openaev() {
  local args=("$ACTION" -p "${PREFIX}-openaev")
  [[ -n "$BUILD_OPENAEV" ]] && args+=(--build "$BUILD_OPENAEV")
  "$SCRIPT_DIR/spawn-openaev.sh" "${args[@]}" "${EXTRA[@]}"
}

run_opencti() {
  local args=("$ACTION" -p "${PREFIX}-opencti")
  [[ -n "$BUILD_OPENCTI" ]] && args+=(--build "$BUILD_OPENCTI")
  "$SCRIPT_DIR/spawn-opencti.sh" "${args[@]}" "${EXTRA[@]}"
}

case "$ACTION" in
  up|down|logs) ;;
  *) echo "Usage: $0 {up|down|logs} --stack openaev|opencti|both [options]" >&2; exit 1 ;;
esac

case "$STACK" in
  openaev) run_openaev ;;
  opencti) run_opencti ;;
  both)
    if [[ "$ACTION" == "logs" ]]; then
      echo "!! --stack both doesn't support 'logs' (ambiguous target)." >&2
      echo "!! Use --stack openaev or --stack opencti instead." >&2
      exit 1
    fi
    run_openaev
    run_opencti
    ;;
  *) echo "Unknown --stack: $STACK (expected openaev|opencti|both)" >&2; exit 1 ;;
esac
