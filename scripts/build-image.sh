#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build-image.sh --image ai-agent-sandbox:latest
EOF
}

image="ai-agent-sandbox:latest"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="$2"
      shift 2
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
repo_root="$(cd "${script_dir}/.." && pwd)"
engine="$("${script_dir}/detect-container-engine.sh")"

cleanup_dir=""

if [[ "${engine}" == "docker" && -z "${DOCKER_CONFIG:-}" ]]; then
  cleanup_dir="$(mktemp -d)"
  trap 'rm -rf "${cleanup_dir}"' EXIT
  mkdir -p "${cleanup_dir}/contexts"
  if [[ -d "${HOME}/.docker/contexts" ]]; then
    cp -R "${HOME}/.docker/contexts/." "${cleanup_dir}/contexts/"
  fi
  if [[ -f "${HOME}/.docker/config.json" ]]; then
    python3 - "${HOME}/.docker/config.json" "${cleanup_dir}/config.json" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
config = json.loads(source.read_text())
config.pop("credsStore", None)
config.pop("credHelpers", None)
target.write_text(json.dumps(config, indent=2) + "\n")
PY
  else
    printf '{\n  "auths": {}\n}\n' > "${cleanup_dir}/config.json"
  fi
  export DOCKER_CONFIG="${cleanup_dir}"
fi

"${engine}" build -f "${repo_root}/Containerfile" -t "${image}" "${repo_root}"
