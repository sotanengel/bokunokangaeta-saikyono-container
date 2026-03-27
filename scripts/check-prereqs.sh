#!/usr/bin/env bash
set -euo pipefail

status=0
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check() {
  local name="$1"
  local command_name="$2"

  if command -v "${command_name}" >/dev/null 2>&1; then
    printf 'ok   %s: %s\n' "${name}" "$(command -v "${command_name}")"
  else
    printf 'miss %s\n' "${name}" >&2
    status=1
  fi
}

check "python3" python3
check "git" git

if engine="$("${script_dir}/detect-container-engine.sh" 2>/dev/null)"; then
  printf 'ok   container-engine-cli: %s\n' "$("${engine}" --version)"
  if "${engine}" info >/dev/null 2>&1; then
    printf 'ok   container-engine-runtime: %s is ready\n' "${engine}"
  else
    printf 'miss container-engine-runtime (%s is installed but not ready)\n' "${engine}" >&2
    if [[ "${engine}" == "podman" && "$(uname -s)" == "Darwin" ]]; then
      printf 'hint run: ./scripts/install-host-tools-macos.sh\n' >&2
      printf 'hint or: podman machine init --now\n' >&2
    elif [[ "${engine}" == "docker" ]]; then
      printf 'hint start the Docker daemon or set DOCKER_HOST to a reachable API socket.\n' >&2
    fi
    status=1
  fi
else
  printf 'miss container-engine (podman or docker)\n' >&2
  status=1
fi

if [[ ${status} -ne 0 ]]; then
  printf '\nInstall the missing prerequisites before running make build or make smoke.\n' >&2
fi

exit "${status}"
