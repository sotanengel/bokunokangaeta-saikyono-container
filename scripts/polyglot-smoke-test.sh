#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  polyglot-smoke-test.sh [--image IMAGE] [--group core|extended|all]
EOF
}

image="ai-agent-sandbox:latest"
group="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      image="$2"
      shift 2
      ;;
    --group)
      group="$2"
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_core() {
  "${script_dir}/run-sandbox.sh" --image "${image}" --online --reason "polyglot-bootstrap-core" -- bootstrap-languages --core
  "${script_dir}/run-sandbox.sh" --image "${image}" --reason "polyglot-smoke-core" -- bash -c '
    set -euo pipefail
    python3 /workspace/examples/python/main.py | grep -qx "python-ok"
    node /workspace/examples/node/index.mjs | grep -qx "node-ok"
    go run /workspace/examples/go/main.go | grep -qx "go-ok"
    cargo run --quiet --manifest-path /workspace/examples/rust/Cargo.toml --target-dir /home/agent/.cache/rust-target | grep -qx "rust-ok"
  '
}

run_extended() {
  "${script_dir}/run-sandbox.sh" --image "${image}" --online --reason "polyglot-bootstrap-extended" -- bootstrap-languages --polyglot
  "${script_dir}/run-sandbox.sh" --image "${image}" --reason "polyglot-smoke-extended" -- bash -c '
    set -euo pipefail
    mkdir -p /home/agent/.cache/java-classes
    javac -d /home/agent/.cache/java-classes /workspace/examples/java/Main.java
    java -cp /home/agent/.cache/java-classes Main | grep -qx "java-ok"
    ruby /workspace/examples/ruby/main.rb | grep -qx "ruby-ok"
    bun run /workspace/examples/bun/index.ts | grep -qx "bun-ok"
    deno run /workspace/examples/deno/main.ts | grep -qx "deno-ok"
  '
}

case "${group}" in
  core)
    run_core
    ;;
  extended)
    run_extended
    ;;
  all)
    run_core
    run_extended
    ;;
  *)
    printf 'unsupported group: %s\n' "${group}" >&2
    exit 1
    ;;
esac
