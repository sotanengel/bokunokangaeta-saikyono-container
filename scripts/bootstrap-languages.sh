#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bootstrap-languages --core
  bootstrap-languages --polyglot
EOF
}

profile="core"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --core)
      profile="core"
      shift
      ;;
    --polyglot|--all)
      profile="polyglot"
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

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required" >&2
  exit 1
fi

config_file="${MISE_CONFIG_FILE:-${PWD}/.mise.toml}"
if [[ ! -f "${config_file}" && -f /workspace/.mise.toml ]]; then
  config_file=/workspace/.mise.toml
fi

if [[ ! -f "${config_file}" ]]; then
  echo "could not find .mise.toml" >&2
  exit 1
fi

export MISE_CONFIG_FILE="${config_file}"

if [[ -d "$(dirname "${config_file}")" ]]; then
  cd "$(dirname "${config_file}")"
fi

case "${profile}" in
  core)
    tools=(node python go rust)
    ;;
  polyglot)
    tools=(node python go rust java ruby bun deno)
    ;;
  *)
    echo "unsupported profile: ${profile}" >&2
    exit 1
    ;;
esac

if printf '%s\n' "${tools[@]}" | grep -qx ruby; then
  export MISE_RUBY_COMPILE=false
fi

mise install "${tools[@]}"
mise reshim
mise ls --installed
