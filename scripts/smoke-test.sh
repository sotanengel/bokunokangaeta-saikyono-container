#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE:-ai-agent-sandbox:latest}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/run-sandbox.sh" --image "${image}" -- bash -lc '
  set -euo pipefail
  test "$(id -u)" != "0"
  command -v node >/dev/null
  command -v npm >/dev/null
  command -v python3 >/dev/null
  command -v uv >/dev/null
  command -v mise >/dev/null
  command -v git >/dev/null
  test -x /usr/bin/tini
  test -f /workspace/AGENTS.md
  test -f /workspace/Containerfile
'
