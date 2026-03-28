#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
venv_dir="${repo_root}/.sandbox/pre-commit-venv"
precommit_version="4.3.0"

mkdir -p "${repo_root}/.sandbox"

if [[ ! -x "${venv_dir}/bin/pre-commit" ]]; then
  python3 -m venv "${venv_dir}"
fi

"${venv_dir}/bin/python" -m pip install --upgrade --disable-pip-version-check "pre-commit==${precommit_version}" >/dev/null

cd "${repo_root}"

if [[ $# -eq 0 ]]; then
  exec "${venv_dir}/bin/pre-commit" run --all-files
fi

exec "${venv_dir}/bin/pre-commit" "$@"
