#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

cd "${repo_root}"

uid="$(id -u)"
gid="$(id -g)"

run_output="$(
  CONTAINER_ENGINE=docker "${script_dir}/run-sandbox.sh" --dry-run --image ai-agent-sandbox:test
)"

grep -Fqx "engine=docker" <<< "${run_output}"
grep -Fqx "workspace=${repo_root}" <<< "${run_output}"
grep -Fqx "home_mount=${repo_root}/.sandbox/home" <<< "${run_output}"
grep -Fqx "runtime_uid=${uid}" <<< "${run_output}"
grep -Fqx "runtime_gid=${gid}" <<< "${run_output}"
grep -F -- "--user ${uid}:${gid}" <<< "${run_output}" >/dev/null

compose_output="$(
  COMPOSE_CMD='docker compose' "${script_dir}/compose-shell.sh" --dry-run
)"

grep -Fqx "compose_engine=docker" <<< "${compose_output}"
grep -Fqx "workspace=${repo_root}" <<< "${compose_output}"
grep -Fqx "compose_file=${repo_root}/compose.yaml" <<< "${compose_output}"
grep -Fqx "sandbox_uid=${uid}" <<< "${compose_output}"
grep -Fqx "sandbox_gid=${gid}" <<< "${compose_output}"
grep -F -- "SANDBOX_UID=${uid}" <<< "${compose_output}" >/dev/null
grep -F -- "SANDBOX_GID=${gid}" <<< "${compose_output}" >/dev/null

printf '%s\n' "Sandbox runtime config checks completed."
