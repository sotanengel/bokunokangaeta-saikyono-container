#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  write-audit-log.sh --event start|finish --mode run|compose-run --engine ENGINE --target TARGET \
    --workspace PATH --online true|false [--container-name NAME] [--agent NAME] [--reason TEXT] \
    [--command-preview TEXT] [--env-forwarded CSV] [--network-mode offline|online] \
    [--gitconfig-mounted true|false] [--exit-code N]
EOF
}

event=""
mode=""
engine=""
target=""
workspace=""
online="false"
container_name=""
agent=""
reason="unspecified"
command_preview=""
env_forwarded=""
network_mode=""
gitconfig_mounted="false"
exit_code=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)
      event="$2"
      shift 2
      ;;
    --mode)
      mode="$2"
      shift 2
      ;;
    --engine)
      engine="$2"
      shift 2
      ;;
    --target)
      target="$2"
      shift 2
      ;;
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --online)
      online="$2"
      shift 2
      ;;
    --container-name)
      container_name="$2"
      shift 2
      ;;
    --agent)
      agent="$2"
      shift 2
      ;;
    --reason)
      reason="$2"
      shift 2
      ;;
    --command-preview)
      command_preview="$2"
      shift 2
      ;;
    --env-forwarded)
      env_forwarded="$2"
      shift 2
      ;;
    --network-mode)
      network_mode="$2"
      shift 2
      ;;
    --gitconfig-mounted)
      gitconfig_mounted="$2"
      shift 2
      ;;
    --exit-code)
      exit_code="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in event mode engine target workspace; do
  if [[ -z "${!required}" ]]; then
    printf 'missing required option: %s\n' "${required}" >&2
    exit 1
  fi
done

state_root="${XDG_STATE_HOME:-${HOME}/.local/state}"
log_dir="${state_root}/ai-agent-sandbox/audit"
log_file="${log_dir}/container-runs.jsonl"
mkdir -p "${log_dir}"

python3 - "${log_file}" "${event}" "${mode}" "${engine}" "${target}" "${workspace}" "${online}" "${container_name}" "${agent}" "${reason}" "${command_preview}" "${env_forwarded}" "${network_mode}" "${gitconfig_mounted}" "${exit_code}" <<'PY'
import json
import os
import pathlib
import sys
from datetime import datetime, timezone

(
    log_file,
    event,
    mode,
    engine,
    target,
    workspace,
    online,
    container_name,
    agent,
    reason,
    command_preview,
    env_forwarded,
    network_mode,
    gitconfig_mounted,
    exit_code,
) = sys.argv[1:]

record = {
    "timestamp_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "event": event,
    "mode": mode,
    "engine": engine,
    "target": target,
    "workspace": workspace,
    "workspace_name": pathlib.Path(workspace).name,
    "online": online.lower() == "true",
    "network_mode": network_mode or ("online" if online.lower() == "true" else "offline"),
    "container_name": container_name or None,
    "agent": agent or None,
    "reason": reason,
    "command_preview": command_preview or None,
    "env_forwarded": [item for item in env_forwarded.split(",") if item],
    "gitconfig_mounted": gitconfig_mounted.lower() == "true",
    "actor": {
        "user": os.environ.get("USER", "unknown"),
        "uid": os.getuid(),
        "gid": os.getgid(),
    },
    "security_profile": {
        "read_only_rootfs": True,
        "cap_drop_all": True,
        "no_new_privileges": True,
        "tmpfs_tmp": True,
        "tmpfs_var_tmp": True,
    },
}

if exit_code:
    record["exit_code"] = int(exit_code)

path = pathlib.Path(log_file)
with path.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, ensure_ascii=True, separators=(",", ":")) + "\n")
PY
