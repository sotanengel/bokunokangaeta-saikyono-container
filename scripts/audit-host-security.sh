#!/usr/bin/env bash
set -euo pipefail

print_line() {
  printf '%-5s %s\n' "$1" "$2"
}

print_line "info" "current-user: ${USER:-unknown} (uid $(id -u), gid $(id -g))"
print_line "info" "audit-log: ${XDG_STATE_HOME:-${HOME}/.local/state}/ai-agent-sandbox/audit/container-runs.jsonl"

if command -v docker >/dev/null 2>&1; then
  print_line "ok" "docker-cli: $(docker --version)"
  if docker info >/dev/null 2>&1; then
    docker_context="$(docker context show 2>/dev/null || true)"
    print_line "warn" "docker-access: current user can reach the Docker API${docker_context:+ (context ${docker_context})}; treat this as privileged access"
    if [[ "$(uname -s)" == "Linux" ]] && id -Gn | tr ' ' '\n' | grep -qx docker; then
      print_line "warn" "docker-group: current user belongs to the docker group"
    fi
  else
    print_line "info" "docker-access: daemon not reachable"
  fi
else
  print_line "miss" "docker-cli"
fi

if command -v podman >/dev/null 2>&1; then
  print_line "ok" "podman-cli: $(podman --version)"
  if podman info >/dev/null 2>&1; then
    rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)"
    socket_path="$(podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null || true)"
    if [[ "${rootless}" == "true" ]]; then
      print_line "ok" "podman-rootless: true${socket_path:+ (${socket_path})}"
    else
      print_line "warn" "podman-rootless: false${socket_path:+ (${socket_path})}"
    fi
  else
    print_line "info" "podman-access: runtime not reachable"
  fi
else
  print_line "miss" "podman-cli"
fi
