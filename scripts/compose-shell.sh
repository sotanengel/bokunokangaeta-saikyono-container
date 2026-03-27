#!/usr/bin/env bash
set -euo pipefail

service="sandbox"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --online)
      service="sandbox-online"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  compose-shell.sh
  compose-shell.sh --online
EOF
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -n "${COMPOSE_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  compose_cmd=(${COMPOSE_CMD})
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  compose_cmd=(podman compose)
elif command -v podman-compose >/dev/null 2>&1; then
  compose_cmd=(podman-compose)
else
  printf '%s\n' "No compose command found. Install docker compose, podman compose, or podman-compose." >&2
  exit 1
fi

mkdir -p .sandbox/home
exec "${compose_cmd[@]}" run --rm --service-ports "${service}" bash
