#!/usr/bin/env bash
set -euo pipefail

service="sandbox"
online="false"
reason="compose-shell"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --online)
      service="sandbox-online"
      online="true"
      shift
      ;;
    --reason)
      reason="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  compose-shell.sh
  compose-shell.sh --online [--reason TEXT]
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

if [[ "${online}" == "true" && "${reason}" == "compose-shell" ]]; then
  printf '%s\n' "warning: online compose run requested without --reason; logging as compose-shell." >&2
fi

mkdir -p .sandbox/home
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(pwd)"
compose_engine="${compose_cmd[0]}"
command_preview="bash"

"${script_dir}/write-audit-log.sh" \
  --event start \
  --mode compose-run \
  --engine "${compose_engine}" \
  --target "${service}" \
  --workspace "${workspace}" \
  --online "${online}" \
  --agent compose \
  --reason "${reason}" \
  --command-preview "${command_preview}" \
  --network-mode "$([[ "${online}" == "true" ]] && printf '%s' online || printf '%s' offline)"

set +e
"${compose_cmd[@]}" run --rm "${service}" bash
exit_code=$?
set -e

"${script_dir}/write-audit-log.sh" \
  --event finish \
  --mode compose-run \
  --engine "${compose_engine}" \
  --target "${service}" \
  --workspace "${workspace}" \
  --online "${online}" \
  --agent compose \
  --reason "${reason}" \
  --command-preview "${command_preview}" \
  --network-mode "$([[ "${online}" == "true" ]] && printf '%s' online || printf '%s' offline)" \
  --exit-code "${exit_code}"

exit "${exit_code}"
