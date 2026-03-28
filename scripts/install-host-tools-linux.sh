#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-host-tools-linux.sh [--engine podman|docker|both] [--no-sudo]

Installs container host tools on Linux.
Supported package managers:
  - apt-get: Podman and Docker
  - dnf: Podman
EOF
}

engine="podman"
sudo_cmd="sudo"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)
      engine="$2"
      shift 2
      ;;
    --no-sudo)
      sudo_cmd=""
      shift
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

if [[ "$(uname -s)" != "Linux" ]]; then
  printf '%s\n' "This installer is for Linux only." >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  sudo_cmd=""
elif [[ -n "${sudo_cmd}" ]] && ! command -v sudo >/dev/null 2>&1; then
  printf '%s\n' "sudo is required unless you run as root or pass --no-sudo." >&2
  exit 1
fi

run_pkg() {
  if [[ -n "${sudo_cmd}" ]]; then
    "${sudo_cmd}" "$@"
  else
    "$@"
  fi
}

if command -v apt-get >/dev/null 2>&1; then
  pkg_manager="apt-get"
elif command -v dnf >/dev/null 2>&1; then
  pkg_manager="dnf"
else
  printf '%s\n' "unsupported Linux package manager; expected apt-get or dnf." >&2
  exit 1
fi

case "${pkg_manager}" in
  apt-get)
    podman_packages=(podman podman-compose uidmap slirp4netns fuse-overlayfs)
    docker_packages=(docker.io docker-compose-v2)
    run_pkg apt-get update
    case "${engine}" in
      podman)
        run_pkg apt-get install -y "${podman_packages[@]}"
        ;;
      docker)
        run_pkg apt-get install -y "${docker_packages[@]}"
        ;;
      both)
        run_pkg apt-get install -y "${podman_packages[@]}" "${docker_packages[@]}"
        ;;
      *)
        printf 'unsupported engine mode: %s\n' "${engine}" >&2
        exit 1
        ;;
    esac
    ;;
  dnf)
    podman_packages=(podman podman-compose slirp4netns fuse-overlayfs)
    case "${engine}" in
      podman)
        run_pkg dnf install -y "${podman_packages[@]}"
        ;;
      docker|both)
        printf '%s\n' "Automated Docker installation is not implemented for dnf hosts. Use --engine podman or install Docker from your distribution policy." >&2
        exit 1
        ;;
      *)
        printf 'unsupported engine mode: %s\n' "${engine}" >&2
        exit 1
        ;;
    esac
    ;;
esac

printf '\nInstalled tools:\n'
command -v podman >/dev/null 2>&1 && printf '  %s\n' "$(podman --version)"
command -v docker >/dev/null 2>&1 && printf '  %s\n' "$(docker --version)"
command -v podman-compose >/dev/null 2>&1 && printf '  %s\n' "$(podman-compose version | tail -n 1)"

printf '\nNext steps:\n'
printf '%s\n' "  ./scripts/check-prereqs.sh"
printf '%s\n' "  ./scripts/check-container-engines.sh"
