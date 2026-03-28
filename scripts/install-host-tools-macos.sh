#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-host-tools-macos.sh [--write-shell-profile] [--skip-machine] [--machine-name NAME]

Installs user-local Podman, Podman helper binaries, Docker CLI, and podman-compose on macOS.
By default it also initializes or repairs a Podman machine for local container execution.
If Podman machine startup still fails, the script leaves Docker usable and prints follow-up steps.
EOF
}

note() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

run_podman_machine_cmd() {
  local action="$1"
  local name="$2"
  python3 - "${action}" "${name}" <<'PY'
import subprocess
import sys

action = sys.argv[1]
name = sys.argv[2]

try:
    subprocess.run(
        ["podman", "machine", action, name],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=120,
    )
except subprocess.TimeoutExpired:
    raise SystemExit(124)
except subprocess.CalledProcessError as exc:
    raise SystemExit(exc.returncode)
PY
}

write_shell_profile=0
skip_machine=0
machine_name="podman-machine-default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write-shell-profile)
      write_shell_profile=1
      shift
      ;;
    --skip-machine)
      skip_machine=1
      shift
      ;;
    --machine-name)
      machine_name="$2"
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
  printf '%s\n' "This installer is for macOS only." >&2
  exit 1
fi

for command_name in curl unzip tar pkgutil python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "${command_name}" >&2
    exit 1
  fi
done

case "$(uname -m)" in
  arm64)
    podman_remote_asset="podman-remote-release-darwin_arm64.zip"
    podman_pkg_asset="podman-installer-macos-arm64.pkg"
    docker_arch="aarch64"
    ;;
  x86_64)
    podman_remote_asset="podman-remote-release-darwin_amd64.zip"
    podman_pkg_asset="podman-installer-macos-amd64.pkg"
    docker_arch="x86_64"
    ;;
  *)
    printf 'unsupported architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HOME}/.local/bin"
podman_root="${HOME}/.local/lib/podman"
podman_bin_dir="${podman_root}/bin"
podman_lib_dir="${podman_root}/lib"
containers_conf="${HOME}/.config/containers/containers.conf"
shell_profile="${HOME}/.zprofile"
python_user_bin="${HOME}/Library/Python/$(python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)/bin"

mkdir -p "${bin_dir}" "${podman_bin_dir}" "${podman_lib_dir}" "${HOME}/.config/containers"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

note "Resolving latest Podman release metadata..."
podman_release_json="${tmp_dir}/podman-release.json"
curl -fsSL "https://api.github.com/repos/containers/podman/releases/latest" -o "${podman_release_json}"

podman_remote_url="$(python3 - "${podman_release_json}" "${podman_remote_asset}" <<'PY'
import json
import pathlib
import sys

release = json.loads(pathlib.Path(sys.argv[1]).read_text())
target = sys.argv[2]
for asset in release["assets"]:
    if asset["name"] == target:
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit(f"missing Podman asset: {target}")
PY
)"

podman_pkg_url="$(python3 - "${podman_release_json}" "${podman_pkg_asset}" <<'PY'
import json
import pathlib
import sys

release = json.loads(pathlib.Path(sys.argv[1]).read_text())
target = sys.argv[2]
for asset in release["assets"]:
    if asset["name"] == target:
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit(f"missing Podman asset: {target}")
PY
)"

note "Downloading Podman CLI..."
curl -fsSL "${podman_remote_url}" -o "${tmp_dir}/podman-remote.zip"
unzip -qo "${tmp_dir}/podman-remote.zip" -d "${tmp_dir}/podman-remote"
install -m 0755 "${tmp_dir}/podman-remote/podman" "${bin_dir}/podman"

note "Downloading Podman helper bundle..."
curl -fsSL "${podman_pkg_url}" -o "${tmp_dir}/podman-installer.pkg"
pkgutil --expand-full "${tmp_dir}/podman-installer.pkg" "${tmp_dir}/podman-pkg"
cp -R "${tmp_dir}/podman-pkg/podman.pkg/Payload/podman/bin/." "${podman_bin_dir}/"
cp -R "${tmp_dir}/podman-pkg/podman.pkg/Payload/podman/lib/." "${podman_lib_dir}/"
chmod 0755 "${podman_bin_dir}"/*
ln -sfn "${podman_bin_dir}/podman-mac-helper" "${bin_dir}/podman-mac-helper"

note "Resolving latest Docker CLI bundle..."
docker_index="${tmp_dir}/docker-index.html"
curl -fsSL "https://download.docker.com/mac/static/stable/${docker_arch}/" -o "${docker_index}"

docker_archive="$(python3 - "${docker_index}" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
matches = re.findall(r'href="(docker-(\d+)\.(\d+)\.(\d+)\.tgz)"', text)
if not matches:
    raise SystemExit("missing Docker CLI archive")

best_name = None
best_version = None
for name, major, minor, patch in matches:
    version = (int(major), int(minor), int(patch))
    if best_version is None or version > best_version:
        best_version = version
        best_name = name

print(best_name)
PY
)"

note "Downloading Docker CLI..."
curl -fsSL "https://download.docker.com/mac/static/stable/${docker_arch}/${docker_archive}" -o "${tmp_dir}/docker.tgz"
tar -xzf "${tmp_dir}/docker.tgz" -C "${tmp_dir}"
install -m 0755 "${tmp_dir}/docker/docker" "${bin_dir}/docker"
if [[ -x /Applications/Docker.app/Contents/Resources/bin/docker-credential-desktop ]]; then
  ln -sfn /Applications/Docker.app/Contents/Resources/bin/docker-credential-desktop "${bin_dir}/docker-credential-desktop"
fi

note "Installing podman-compose..."
python3 -m pip install --user --upgrade podman-compose

python3 - "${containers_conf}" "${podman_bin_dir}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
helper_dir = sys.argv[2]
managed = 'helper_binaries_dir = ["%s"]' % helper_dir
text = path.read_text() if path.exists() else ""

if "helper_binaries_dir" in text:
    text = re.sub(
        r'(?m)^\s*helper_binaries_dir\s*=.*$',
        managed,
        text,
        count=1,
    )
elif "[engine]" in text:
    text = text.replace("[engine]\n", "[engine]\n" + managed + "\n", 1)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "[engine]\n" + managed + "\n"

path.write_text(text)
PY

if [[ ${write_shell_profile} -eq 1 ]]; then
  python3 - "${shell_profile}" "${python_user_bin}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
python_user_bin = sys.argv[2]
text = path.read_text() if path.exists() else ""
block = f"""# >>> ai-agent-sandbox
PATH="$HOME/.local/bin:{python_user_bin}:${{PATH}}"
export PATH
if [ -z "${{DOCKER_HOST:-}}" ] && command -v podman >/dev/null 2>&1; then
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    _podman_machine="${{PODMAN_MACHINE_NAME:-podman-machine-default}}"
    _podman_socket="$(podman machine inspect "${{_podman_machine}}" --format '{{{{.ConnectionInfo.PodmanSocket.Path}}}}' 2>/dev/null || true)"
    if [ -n "${{_podman_socket}}" ] && [ -S "${{_podman_socket}}" ] && podman info >/dev/null 2>&1; then
      export DOCKER_HOST="unix://${{_podman_socket}}"
    fi
    unset _podman_machine _podman_socket
  fi
fi
# <<< ai-agent-sandbox
"""

pattern = re.compile(r"# >>> ai-agent-sandbox\n.*?# <<< ai-agent-sandbox\n?", re.S)
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += ("\n" if text else "") + block

path.write_text(text)
PY
fi

export PATH="${bin_dir}:${python_user_bin}:${PATH}"

podman_machine_ready=0
docker_ready=0

if docker info >/dev/null 2>&1; then
  docker_ready=1
fi

if [[ ${skip_machine} -eq 0 ]]; then
  if podman machine inspect "${machine_name}" >/dev/null 2>&1; then
    note "Found Podman machine: ${machine_name}"
  else
    podman system connection rm "${machine_name}" >/dev/null 2>&1 || true
    podman system connection rm "${machine_name}-root" >/dev/null 2>&1 || true
    note "Initializing Podman machine: ${machine_name}"
    if ! run_podman_machine_cmd init "${machine_name}"; then
      warn "Podman machine initialization did not complete for ${machine_name}."
    fi
  fi

  if ! "${script_dir}/repair-podman-machine-macos.sh" --machine-name "${machine_name}"; then
    warn "could not apply the Podman machine repair pass for ${machine_name}"
  fi

  podman system connection default "${machine_name}" >/dev/null 2>&1 || true

  note "Starting Podman machine: ${machine_name}"
  if "${script_dir}/start-podman-machine-macos.sh" --machine-name "${machine_name}"; then
    podman_machine_ready=1
  else
    warn "Podman machine startup did not become ready on this host."
    warn "You can retry with: ./scripts/start-podman-machine-macos.sh --machine-name ${machine_name}"
    warn "You can retry with: ./scripts/repair-podman-machine-macos.sh --machine-name ${machine_name}"
    warn "Docker remains usable if Docker Desktop is running."
  fi
fi

if [[ ${podman_machine_ready} -eq 1 ]]; then
  socket_path="$(podman machine inspect "${machine_name}" --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
  if [[ ${docker_ready} -eq 0 ]]; then
    export DOCKER_HOST="unix://${socket_path}"
  fi
fi

printf '\nInstalled tools:\n'
printf '  %s\n' "$(podman --version)"
printf '  %s\n' "$(docker --version)"
printf '  %s\n' "$(podman-compose version | tail -n 1)"

if [[ -x "${script_dir}/check-container-engines.sh" ]]; then
  printf '\nEngine status:\n'
  "${script_dir}/check-container-engines.sh" || true
fi
