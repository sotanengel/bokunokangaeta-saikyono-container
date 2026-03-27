#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${CONTAINER_ENGINE:-}" ]]; then
  echo "${CONTAINER_ENGINE}"
  exit 0
fi

available=()

for engine in podman docker; do
  if command -v "${engine}" >/dev/null 2>&1; then
    available+=("${engine}")
    if "${engine}" info >/dev/null 2>&1; then
      echo "${engine}"
      exit 0
    fi
  fi
done

if [[ ${#available[@]} -gt 0 ]]; then
  echo "${available[0]}"
  exit 0
fi

echo "podman or docker is required" >&2
exit 1
