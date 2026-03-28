#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-sandbox.sh --image ai-agent-sandbox:latest [--online] [--reason TEXT] [--agent shell]
  run-sandbox.sh --image ai-agent-sandbox:latest [--reason TEXT] -- command arg1 arg2
EOF
}

image="ai-agent-sandbox:latest"
workspace="$(pwd)"
agent="shell"
online=false
reason="unspecified"
allow_unsafe_workspace=false
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
    --reason)
      reason="$2"
      shift 2
      ;;
    --allow-unsafe-workspace)
      allow_unsafe_workspace=true
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
    if [[ "${allow_unsafe_workspace}" == true ]]; then
      printf 'warning: allowing high-risk workspace mount: %s (%s)\n' "${candidate}" "${unsafe_reason}" >&2
    else
      printf 'refusing high-risk workspace mount: %s (%s)\n' "${candidate}" "${unsafe_reason}" >&2
      printf '%s\n' 'hint use a project directory or pass --allow-unsafe-workspace if this is intentional.' >&2
      exit 1
    fi
  fi
}

validate_workspace "${workspace}"

home_mount="${workspace}/.sandbox/home"
mkdir -p "${home_mount}"

if [[ "${online}" == true && "${reason}" == "unspecified" ]]; then
  printf '%s\n' "warning: online run requested without --reason; logging as unspecified." >&2
fi

container_timestamp="$(date -u +%Y%m%d%H%M%S)"
container_name="ai-agent-sandbox-${agent}-${container_timestamp}-$$"
network_mode="offline"
gitconfig_mounted=false
declare -a forwarded_env=()

declare -a run_args=(
  run
  --rm
  --read-only
  --cap-drop=ALL
  --security-opt=no-new-privileges
  --pids-limit=512
  --user=agent
  --workdir=/workspace
  --tmpfs=/tmp:rw,nosuid,nodev,noexec,size=1073741824
  --tmpfs=/var/tmp:rw,nosuid,nodev,noexec,size=268435456
  --name
  "${container_name}"
  --label
  io.github.ai-agent-sandbox.managed=true
  --label
  "io.github.ai-agent-sandbox.agent=${agent}"
  --label
  "io.github.ai-agent-sandbox.online=${online}"
  --label
  "io.github.ai-agent-sandbox.workspace=$(basename "${workspace}")"
  --label
  "io.github.ai-agent-sandbox.invoker=${USER:-unknown}"
  --mount
  "type=bind,src=${workspace},dst=/workspace"
  --mount
  "type=bind,src=${home_mount},dst=/home/agent"
)

if [[ "${online}" == false ]]; then
  run_args+=(--network=none)
else
  network_mode="online"
fi

if [[ -f "${HOME}/.gitconfig" ]]; then
  run_args+=(--mount "type=bind,src=${HOME}/.gitconfig,dst=/home/agent/.gitconfig,readonly")
  gitconfig_mounted=true
fi

for env_var in "${env_vars[@]}"; do
  if [[ -n "${!env_var-}" ]]; then
    run_args+=(-e "${env_var}")
    forwarded_env+=("${env_var}")
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
    default_command=(bash -c "printf '%s\n' 'GitHub Copilot is supported via .github/copilot-instructions.md and .devcontainer/devcontainer.json.'")
    ;;
  cursor)
    default_command=(bash -c "printf '%s\n' 'Cursor is supported via .cursor/rules/00-project.mdc and .devcontainer/devcontainer.json.'")
    ;;
  *)
    echo "unsupported agent: ${agent}" >&2
    exit 1
    ;;
esac

if [[ ${#custom_command[@]} -gt 0 ]]; then
  default_command=("${custom_command[@]}")
fi

command_preview="$(printf '%q ' "${default_command[@]}")"
command_preview="${command_preview% }"
forwarded_env_csv="$(IFS=,; printf '%s' "${forwarded_env[*]-}")"

"${script_dir}/write-audit-log.sh" \
  --event start \
  --mode run \
  --engine "${engine}" \
  --target "${image}" \
  --workspace "${workspace}" \
  --online "${online}" \
  --container-name "${container_name}" \
  --agent "${agent}" \
  --reason "${reason}" \
  --command-preview "${command_preview}" \
  --env-forwarded "${forwarded_env_csv}" \
  --network-mode "${network_mode}" \
  --gitconfig-mounted "${gitconfig_mounted}"

set +e
"${engine}" "${run_args[@]}" "${image}" "${default_command[@]}"
exit_code=$?
set -e

"${script_dir}/write-audit-log.sh" \
  --event finish \
  --mode run \
  --engine "${engine}" \
  --target "${image}" \
  --workspace "${workspace}" \
  --online "${online}" \
  --container-name "${container_name}" \
  --agent "${agent}" \
  --reason "${reason}" \
  --command-preview "${command_preview}" \
  --env-forwarded "${forwarded_env_csv}" \
  --network-mode "${network_mode}" \
  --gitconfig-mounted "${gitconfig_mounted}" \
  --exit-code "${exit_code}"

exit "${exit_code}"
