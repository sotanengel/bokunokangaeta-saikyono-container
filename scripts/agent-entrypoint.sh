#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/agent}"
export WORKSPACE="${WORKSPACE:-/workspace}"
export MISE_DATA_DIR="${MISE_DATA_DIR:-${HOME}/.local/share/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-${HOME}/.cache/mise}"
export TMPDIR="${TMPDIR:-${HOME}/.cache/tmp}"
export TMP="${TMP:-${TMPDIR}}"
export TEMP="${TEMP:-${TMPDIR}}"
export PATH="${HOME}/.local/bin:${MISE_DATA_DIR}/shims:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

mkdir -p \
  "${HOME}/.local/bin" \
  "${HOME}/.local/share" \
  "${HOME}/.cache" \
  "${TMPDIR}" \
  "${HOME}/.config" \
  "${MISE_DATA_DIR}" \
  "${MISE_CACHE_DIR}" \
  "${WORKSPACE}"

if command -v corepack >/dev/null 2>&1; then
  corepack enable >/dev/null 2>&1 || true
fi

if [[ -f "${WORKSPACE}/.mise.toml" ]]; then
  export MISE_CONFIG_FILE="${WORKSPACE}/.mise.toml"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

exec "$@"
