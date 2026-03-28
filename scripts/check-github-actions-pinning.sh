#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

python3 - "${repo_root}" <<'PY'
import pathlib
import re
import sys

repo_root = pathlib.Path(sys.argv[1])
targets = [
    repo_root / ".github" / "workflows",
    repo_root / ".github" / "actions",
]

use_pattern = re.compile(r"^\s*uses:\s*([\"']?)([^\"'#\s]+)\1")
full_sha_pattern = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
docker_digest_pattern = re.compile(r"^docker://[^@\s]+@sha256:[0-9a-f]{64}$")

files = []
for target in targets:
    if not target.exists():
        continue
    for path in target.rglob("*"):
        if path.suffix not in {".yml", ".yaml"} or not path.is_file():
            continue
        files.append(path)

failures = []
for path in sorted(files):
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        match = use_pattern.match(line)
        if not match:
            continue

        ref = match.group(2)
        if ref.startswith("./"):
            continue
        if full_sha_pattern.fullmatch(ref):
            continue
        if docker_digest_pattern.fullmatch(ref):
            continue

        failures.append(f"{path.relative_to(repo_root)}:{lineno}: uses is not pinned to a full SHA or digest: {ref}")

if failures:
    print("GitHub Actions pinning check failed.", file=sys.stderr)
    for failure in failures:
        print(failure, file=sys.stderr)
    raise SystemExit(1)

print("GitHub Actions refs are pinned to full SHAs or digests.")
PY
