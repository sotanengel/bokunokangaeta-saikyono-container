#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  export-image-artifacts.sh --image IMAGE --output-dir DIR
EOF
}

image=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="$2"
      shift 2
      ;;
    --output-dir)
      output_dir="$2"
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

if [[ -z "${image}" || -z "${output_dir}" ]]; then
  usage >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine="$("${script_dir}/detect-container-engine.sh")"
mkdir -p "${output_dir}"

safe_image_name="$(printf '%s' "${image}" | tr '/:' '__')"
archive_path="${output_dir}/${safe_image_name}.tar"
checksum_path="${archive_path}.sha256"

case "${engine}" in
  docker)
    docker save "${image}" -o "${archive_path}"
    ;;
  podman)
    podman save --format docker-archive -o "${archive_path}" "${image}"
    ;;
  *)
    printf 'unsupported engine: %s\n' "${engine}" >&2
    exit 1
    ;;
esac

shasum -a 256 "${archive_path}" > "${checksum_path}"
printf '%s\n' "${archive_path}"
printf '%s\n' "${checksum_path}"
