#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE:-ai-agent-sandbox:latest}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audit_log="${XDG_STATE_HOME:-${HOME}/.local/state}/ai-agent-sandbox/audit/container-runs.jsonl"
before_lines=0

if [[ -f "${audit_log}" ]]; then
  before_lines="$(wc -l < "${audit_log}" | tr -d ' ')"
fi

smoke_command="$(cat <<'EOF'
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
EOF
)"

"${script_dir}/run-sandbox.sh" --image "${image}" --reason "smoke-test" -- bash -c "${smoke_command}"

if "${script_dir}/run-sandbox.sh" --image "${image}" --workspace "${HOME}" --reason "unsafe-workspace-check" -- bash -c 'true' >/dev/null 2>&1; then
  printf '%s\n' "run-sandbox.sh should reject mounting the user home as /workspace." >&2
  exit 1
fi

if [[ ! -f "${audit_log}" ]]; then
  printf 'missing audit log: %s\n' "${audit_log}" >&2
  exit 1
fi

python3 - "${audit_log}" "${before_lines}" "${image}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
before = int(sys.argv[2])
image = sys.argv[3]
records = [json.loads(line) for line in path.read_text().splitlines()[before:]]
records = [record for record in records if record.get("reason") == "smoke-test" and record.get("target") == image]

if len(records) < 2:
    raise SystemExit("expected at least two new smoke-test audit records")

start_record = records[-2]
finish_record = records[-1]

assert start_record["event"] == "start", start_record
assert finish_record["event"] == "finish", finish_record
assert start_record["target"] == image, start_record
assert finish_record["target"] == image, finish_record
assert start_record["online"] is False, start_record
assert finish_record["exit_code"] == 0, finish_record
assert start_record["security_profile"]["read_only_rootfs"] is True, start_record
assert finish_record["security_profile"]["no_new_privileges"] is True, finish_record
PY
