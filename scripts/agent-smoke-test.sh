#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  agent-smoke-test.sh [--image IMAGE] [--agent NAME]

Supported agents:
  codex
  claude
  gemini
  aider
  copilot
  cursor
  all
EOF
}

image="ai-agent-sandbox:latest"
agent="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="$2"
      shift 2
      ;;
    --agent)
      agent="$2"
      shift 2
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

verify_cli_agent() {
  local name="$1"
  local install_flag="--${name}"

  "${script_dir}/run-sandbox.sh" --image "${image}" --online --reason "agent-install-${name}" -- install-agents "${install_flag}"
  "${script_dir}/run-sandbox.sh" --image "${image}" --reason "agent-smoke-${name}" -- bash -c "
    set -euo pipefail
    command -v ${name} >/dev/null
    ${name} --version >/dev/null
  "
}

verify_ide_agent() {
  local name="$1"
  case "${name}" in
    copilot)
      test -f "${repo_root}/.github/copilot-instructions.md"
      "${script_dir}/run-sandbox.sh" --image "${image}" --reason "agent-smoke-copilot" --agent copilot | grep -q "GitHub Copilot is supported"
      ;;
    cursor)
      test -f "${repo_root}/.cursor/rules/00-project.mdc"
      "${script_dir}/run-sandbox.sh" --image "${image}" --reason "agent-smoke-cursor" --agent cursor | grep -q "Cursor is supported"
      ;;
    *)
      printf 'unsupported IDE agent: %s\n' "${name}" >&2
      exit 1
      ;;
  esac
}

run_one() {
  case "$1" in
    codex|claude|gemini|aider)
      verify_cli_agent "$1"
      ;;
    copilot|cursor)
      verify_ide_agent "$1"
      ;;
    *)
      printf 'unsupported agent: %s\n' "$1" >&2
      exit 1
      ;;
  esac
}

case "${agent}" in
  all)
    for item in codex claude gemini aider copilot cursor; do
      run_one "${item}"
    done
    ;;
  *)
    run_one "${agent}"
    ;;
esac
