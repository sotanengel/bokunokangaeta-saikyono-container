#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  start-podman-machine-macos.sh [--machine-name NAME] [--wait-seconds SECONDS] [--terminal-app APP] [--no-gui-fallback]

Starts a Podman machine on macOS and waits until the API socket is reachable.
It first tries a direct start, then falls back to launching the start command in a user Terminal session.
EOF
}

machine_name="podman-machine-default"
wait_seconds=90
terminal_app="Terminal"
gui_fallback=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --machine-name)
      machine_name="$2"
      shift 2
      ;;
    --wait-seconds)
      wait_seconds="$2"
      shift 2
      ;;
    --terminal-app)
      terminal_app="$2"
      shift 2
      ;;
    --no-gui-fallback)
      gui_fallback=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' "This helper is for macOS only." >&2
  exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
  printf '%s\n' "podman is required." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "python3 is required." >&2
  exit 1
fi

if ! podman machine inspect "${machine_name}" >/dev/null 2>&1; then
  printf 'machine not found: %s\n' "${machine_name}" >&2
  exit 1
fi

run_start_with_timeout() {
  python3 - "${machine_name}" <<'PY'
import subprocess
import sys

name = sys.argv[1]

try:
    subprocess.run(
        ["podman", "machine", "start", name],
        check=True,
        timeout=120,
    )
except subprocess.TimeoutExpired:
    raise SystemExit(124)
except subprocess.CalledProcessError as exc:
    raise SystemExit(exc.returncode)
PY
}

wait_for_ready() {
  local elapsed=0
  local sleep_step=2
  local socket_path

  while (( elapsed < wait_seconds )); do
    if podman info >/dev/null 2>&1; then
      socket_path="$(podman machine inspect "${machine_name}" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)"
      if [[ -n "${socket_path}" ]]; then
        printf 'ok   podman-runtime: ready (%s)\n' "${socket_path}"
      else
        printf 'ok   podman-runtime: ready\n'
      fi
      return 0
    fi
    sleep "${sleep_step}"
    elapsed=$((elapsed + sleep_step))
  done

  return 1
}

start_in_terminal() {
  local effective_path="${PATH}"
  osascript - "${terminal_app}" "${machine_name}" "${effective_path}" <<'APPLESCRIPT'
on run argv
  set terminalApp to item 1 of argv
  set machineName to item 2 of argv
  set pathValue to item 3 of argv
  set startCmd to "PATH=" & quoted form of pathValue & "; export PATH; podman machine start " & quoted form of machineName & "; exit"
  tell application terminalApp
    activate
    do script startCmd
  end tell
end run
APPLESCRIPT
}

podman system connection default "${machine_name}" >/dev/null 2>&1 || true

if podman info >/dev/null 2>&1; then
  wait_for_ready
  exit 0
fi

printf 'info  podman-machine: starting %s directly\n' "${machine_name}"
if run_start_with_timeout && wait_for_ready; then
  exit 0
fi

if [[ ${gui_fallback} -eq 0 ]]; then
  printf 'warn  podman-runtime: direct start did not become ready\n' >&2
  exit 1
fi

if ! command -v osascript >/dev/null 2>&1; then
  printf 'warn  podman-runtime: direct start did not become ready and osascript is unavailable\n' >&2
  exit 1
fi

printf 'info  podman-machine: retrying via %s user session\n' "${terminal_app}"
start_in_terminal

if wait_for_ready; then
  exit 0
fi

printf 'warn  podman-runtime: %s did not become ready within %ss\n' "${machine_name}" "${wait_seconds}" >&2
exit 1
