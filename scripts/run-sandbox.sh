#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-sandbox.sh --image ai-agent-sandbox:latest [--online] [--agent shell]
  run-sandbox.sh --image ai-agent-sandbox:latest -- command arg1 arg2
EOF
}

image="ai-agent-sandbox:latest"
workspace="$(pwd)"
agent="shell"
online=false
declare -a custom_command=()
declare -a env_vars=(
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  GEMINI_API_KEY
  GOOGLE_API_KEY
  GITHUB_TOKEN
  HTTP_PROXY
  HTTPS_PROXY
  NO_PROXY
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="$2"
      shift 2
      ;;
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --agent)
      agent="$2"
      shift 2
      ;;
    --online)
      online=true
      shift
      ;;
    --)
      shift
      custom_command=("$@")
      break
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine="$("${script_dir}/detect-container-engine.sh")"
workspace="$(cd "${workspace}" && pwd)"
home_mount="${workspace}/.sandbox/home"
mkdir -p "${home_mount}"

declare -a run_args=(
  run
  --rm
  --init
  --read-only
  --cap-drop=ALL
  --security-opt=no-new-privileges
  --pids-limit=512
  --user=agent
  --workdir=/workspace
  --tmpfs=/tmp:rw,nosuid,nodev,noexec,size=1073741824
  --tmpfs=/var/tmp:rw,nosuid,nodev,noexec,size=268435456
  --mount
  "type=bind,src=${workspace},dst=/workspace,rw"
  --mount
  "type=bind,src=${home_mount},dst=/home/agent,rw"
)

if [[ "${online}" == false ]]; then
  run_args+=(--network=none)
fi

if [[ -f "${HOME}/.gitconfig" ]]; then
  run_args+=(--mount "type=bind,src=${HOME}/.gitconfig,dst=/home/agent/.gitconfig,ro")
fi

for env_var in "${env_vars[@]}"; do
  if [[ -n "${!env_var-}" ]]; then
    run_args+=(-e "${env_var}")
  fi
done

if [[ -t 0 && -t 1 ]]; then
  run_args+=(-it)
fi

declare -a default_command
case "${agent}" in
  shell)
    default_command=(bash)
    ;;
  codex)
    default_command=(codex)
    ;;
  claude)
    default_command=(claude)
    ;;
  gemini)
    default_command=(gemini)
    ;;
  aider)
    default_command=(aider)
    ;;
  copilot)
    default_command=(bash -lc "printf '%s\n' 'GitHub Copilot is supported via .github/copilot-instructions.md and .devcontainer/devcontainer.json.'")
    ;;
  cursor)
    default_command=(bash -lc "printf '%s\n' 'Cursor is supported via .cursor/rules/00-project.mdc and .devcontainer/devcontainer.json.'")
    ;;
  *)
    echo "unsupported agent: ${agent}" >&2
    exit 1
    ;;
esac

if [[ ${#custom_command[@]} -gt 0 ]]; then
  default_command=("${custom_command[@]}")
fi

exec "${engine}" "${run_args[@]}" "${image}" "${default_command[@]}"
