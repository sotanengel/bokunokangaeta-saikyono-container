#!/usr/bin/env bash
set -euo pipefail

ready=0

print_line() {
  printf '%-5s %s\n' "$1" "$2"
}

check_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    print_line "miss" "podman-cli"
    return
  fi

  print_line "ok" "podman-cli: $(podman --version)"

  if podman info >/dev/null 2>&1; then
    ready=1
    print_line "ok" "podman-runtime: ready"
    return
  fi

  print_line "warn" "podman-runtime: installed but not ready"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    local machine_name="${PODMAN_MACHINE_NAME:-podman-machine-default}"
    if podman machine inspect "${machine_name}" >/dev/null 2>&1; then
      local state socket_path
      state="$(podman machine inspect "${machine_name}" --format '{{.State}}')"
      socket_path="$(podman machine inspect "${machine_name}" --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
      print_line "info" "podman-machine: ${machine_name} (${state}, socket ${socket_path})"
      print_line "info" "podman-fix: ./scripts/start-podman-machine-macos.sh --machine-name ${machine_name}"
    else
      print_line "info" "podman-machine: ${machine_name} is not initialized"
    fi
  fi
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    print_line "miss" "docker-cli"
    return
  fi

  print_line "ok" "docker-cli: $(docker --version)"

  if docker info >/dev/null 2>&1; then
    ready=1
    local context server
    context="$(docker context show 2>/dev/null || true)"
    server="$(docker info --format '{{.ServerVersion}}' 2>/dev/null || true)"
    print_line "ok" "docker-runtime: ready${context:+ (context ${context})}${server:+, server ${server}}"
  else
    print_line "warn" "docker-runtime: installed but not ready"
  fi
}

check_podman
check_docker

if [[ ${ready} -eq 0 ]]; then
  exit 1
fi
