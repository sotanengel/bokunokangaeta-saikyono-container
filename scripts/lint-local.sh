#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

cd "${repo_root}"

for file in scripts/*.sh; do
  bash -n "${file}"
done

./scripts/check-github-actions-pinning.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh
fi

python3 -m json.tool .devcontainer/devcontainer.json >/dev/null

yamllint_bin=""
user_base="$(python3 - <<'PY'
import site
print(site.USER_BASE)
PY
)"

for candidate in \
  "${user_base}/bin/yamllint" \
  "${HOME}/.local/bin/yamllint" \
  "$(command -v yamllint 2>/dev/null || true)"; do
  if [[ -n "${candidate}" && -x "${candidate}" ]]; then
    yamllint_bin="${candidate}"
    break
  fi
done

if [[ -n "${yamllint_bin}" ]]; then
  yaml_files=()
  while IFS= read -r file; do
    yaml_files+=("${file}")
  done < <(git ls-files '*.yml' '*.yaml')
  if [[ ${#yaml_files[@]} -gt 0 ]]; then
    "${yamllint_bin}" "${yaml_files[@]}"
  fi
else
  printf '%s\n' "yamllint not found; skipping YAML lint." >&2
fi

if command -v npx >/dev/null 2>&1; then
  markdown_files=()
  while IFS= read -r file; do
    markdown_files+=("${file}")
  done < <(git ls-files '*.md')
  if [[ ${#markdown_files[@]} -gt 0 ]]; then
    npx --yes markdownlint-cli@0.39 "${markdown_files[@]}"
  fi
else
  printf '%s\n' "npx not found; skipping Markdown lint." >&2
fi

if command -v actionlint >/dev/null 2>&1; then
  actionlint
fi

printf '%s\n' "Local lint checks completed."
