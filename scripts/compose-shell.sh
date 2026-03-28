#!/usr/bin/env bash
set -euo pipefail

service="sandbox"
online="false"
reason="compose-shell"
dry_run="false"

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
    --dry-run)
      dry_run="true"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  compose-shell.sh
  compose-shell.sh --online [--reason TEXT]
  compose-shell.sh --dry-run
EOF
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

validate_workspace() {
  local candidate="$1"
  local unsafe_reason=""

  case "${candidate}" in
    /|/Users|/home|/root|/Volumes|/private)
      unsafe_reason="top-level system directory"
      ;;
  esac

  if [[ -z "${unsafe_reason}" && "${candidate}" == "${HOME}" ]]; then
    unsafe_reason="user home directory"
  fi

  if [[ -n "${unsafe_reason}" ]]; then
    printf 'refusing high-risk workspace mount: %s (%s)\n' "${candidate}" "${unsafe_reason}" >&2
    printf '%s\n' 'hint run from a project directory instead of mounting a top-level path.' >&2
    exit 1
  fi
}

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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
workspace="${repo_root}"
compose_engine="${compose_cmd[0]}"
command_preview="bash"
compose_file="${repo_root}/compose.yaml"
sandbox_uid="${SANDBOX_UID:-$(id -u)}"
sandbox_gid="${SANDBOX_GID:-$(id -g)}"

if [[ ! -f "${compose_file}" ]]; then
  printf 'missing compose file: %s\n' "${compose_file}" >&2
  exit 1
fi

validate_workspace "${workspace}"
mkdir -p "${repo_root}/.sandbox/home"
compose_command_preview="$(printf '%q ' env "SANDBOX_UID=${sandbox_uid}" "SANDBOX_GID=${sandbox_gid}" "${compose_cmd[@]}" -f "${compose_file}" run --rm "${service}" bash)"
compose_command_preview="${compose_command_preview% }"

if [[ "${dry_run}" == "true" ]]; then
  printf 'compose_engine=%s\n' "${compose_engine}"
  printf 'workspace=%s\n' "${workspace}"
  printf 'compose_file=%s\n' "${compose_file}"
  printf 'sandbox_uid=%s\n' "${sandbox_uid}"
  printf 'sandbox_gid=%s\n' "${sandbox_gid}"
  printf 'command=%s\n' "${compose_command_preview}"
  exit 0
fi

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
(
  cd "${repo_root}"
  SANDBOX_UID="${sandbox_uid}" SANDBOX_GID="${sandbox_gid}" \
    "${compose_cmd[@]}" -f "${compose_file}" run --rm "${service}" bash
)
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
