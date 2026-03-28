#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  repair-podman-machine-macos.sh [--machine-name NAME] [--target-uid UID]

Repairs a Podman machine definition on macOS so the guest user socket and host forwarding
agree on the same non-root UID. This is safe to run repeatedly.
EOF
}

machine_name="podman-machine-default"
target_uid="1000"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --machine-name)
      machine_name="$2"
      shift 2
      ;;
    --target-uid)
      target_uid="$2"
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' "This helper is for macOS only." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "python3 is required." >&2
  exit 1
fi

config_dir="${HOME}/.config/containers/podman/machine/applehv"
machine_ign="${config_dir}/${machine_name}.ign"
machine_json="${config_dir}/${machine_name}.json"
connections_json="${HOME}/.config/containers/podman-connections.json"

if [[ ! -f "${machine_ign}" || ! -f "${machine_json}" ]]; then
  printf 'machine artifacts not found for %s\n' "${machine_name}" >&2
  exit 1
fi

python3 - "${machine_ign}" "${machine_json}" "${connections_json}" "${machine_name}" "${target_uid}" <<'PY'
import json
import pathlib
import re
import sys
import urllib.parse

ign_path = pathlib.Path(sys.argv[1])
machine_path = pathlib.Path(sys.argv[2])
connections_path = pathlib.Path(sys.argv[3])
machine_name = sys.argv[4]
target_uid = int(sys.argv[5])
messages = []


def backup_once(path: pathlib.Path) -> None:
    backup = path.with_suffix(path.suffix + ".bak")
    if not backup.exists():
        backup.write_text(path.read_text())


ign_data = json.loads(ign_path.read_text())
ign_changed = False

for user in ign_data.get("passwd", {}).get("users", []):
    if user.get("name") == "core" and "uid" in user:
        backup_once(ign_path)
        user.pop("uid", None)
        ign_changed = True
        messages.append("removed core uid override from ignition")

expected_sock = f"/run/user/{target_uid}/podman/podman.sock"
expected_tmpfile = "data:," + urllib.parse.quote(
    f"L+  /run/docker.sock   -    -    -     -   {expected_sock}\n",
    safe="",
)
for entry in ign_data.get("storage", {}).get("files", []):
    if entry.get("path") == "/etc/tmpfiles.d/podman-docker.conf":
        source = entry.setdefault("contents", {}).get("source")
        if source != expected_tmpfile:
            backup_once(ign_path)
            entry["contents"]["source"] = expected_tmpfile
            ign_changed = True
            messages.append(f"rewired guest docker.sock tmpfile to {expected_sock}")
        break

if ign_changed:
    ign_path.write_text(json.dumps(ign_data, separators=(",", ":")))

machine_data = json.loads(machine_path.read_text())
machine_changed = False
host_user = machine_data.setdefault("HostUser", {})
if host_user.get("UID") != target_uid:
    backup_once(machine_path)
    host_user["UID"] = target_uid
    machine_changed = True
    messages.append(f"set HostUser.UID={target_uid}")
if host_user.get("HostUserModified") is not True:
    backup_once(machine_path)
    host_user["HostUserModified"] = True
    machine_changed = True
    messages.append("marked HostUserModified=true")

if machine_changed:
    machine_path.write_text(json.dumps(machine_data, separators=(",", ":")))

if connections_path.exists():
    connections_data = json.loads(connections_path.read_text())
    connections_changed = False
    all_connections = connections_data.get("Connection", {}).get("Connections", {})
    key = machine_name
    if key in all_connections:
      uri = all_connections[key].get("URI", "")
      new_uri = re.sub(
          r"/run/user/\d+/podman/podman\.sock$",
          expected_sock,
          uri,
      )
      if new_uri != uri:
          backup_once(connections_path)
          all_connections[key]["URI"] = new_uri
          connections_changed = True
          messages.append(f"rewired {key} connection URI to {expected_sock}")
    if connections_changed:
        connections_path.write_text(json.dumps(connections_data, separators=(",", ":")))

if messages:
    for message in messages:
        print(message)
else:
    print("no changes needed")
PY
