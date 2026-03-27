#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-agents --all
  install-agents --codex --claude --gemini --aider
  install-agents --copilot
  install-agents --cursor
EOF
}

declare -a agents=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      agents=(codex claude gemini aider copilot cursor)
      shift
      ;;
    --codex)
      agents+=(codex)
      shift
      ;;
    --claude)
      agents+=(claude)
      shift
      ;;
    --gemini)
      agents+=(gemini)
      shift
      ;;
    --aider)
      agents+=(aider)
      shift
      ;;
    --copilot)
      agents+=(copilot)
      shift
      ;;
    --cursor)
      agents+=(cursor)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${#agents[@]} -eq 0 ]]; then
  usage >&2
  exit 1
fi

export NPM_CONFIG_PREFIX="${HOME}/.local"
mkdir -p "${HOME}/.local/bin"

for agent in "${agents[@]}"; do
  case "${agent}" in
    codex)
      npm install -g @openai/codex
      ;;
    claude)
      npm install -g @anthropic-ai/claude-code
      ;;
    gemini)
      npm install -g @google/gemini-cli
      ;;
    aider)
      uv tool install --reinstall --bin-dir "${HOME}/.local/bin" --python python3 aider-chat
      ;;
    copilot)
      printf '%s\n' "GitHub Copilot is supported in this repo via .github/copilot-instructions.md and .devcontainer/devcontainer.json."
      ;;
    cursor)
      printf '%s\n' "Cursor is supported in this repo via .cursor/rules/00-project.mdc and .devcontainer/devcontainer.json."
      ;;
    *)
      echo "unsupported agent: ${agent}" >&2
      exit 1
      ;;
  esac
done
