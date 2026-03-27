# Contributing

## Principles

- Keep the runtime secure by default.
- Preserve Podman and Docker compatibility.
- Do not widen mounts, privileges, or network access without updating docs.
- Keep agent-specific files aligned with `AGENTS.md`.

## Local Checks

```bash
./scripts/install-host-tools-macos.sh --write-shell-profile
./scripts/check-prereqs.sh
./scripts/lint-local.sh
make build
make smoke
```

## Review Checklist

- Does the change keep offline-by-default behavior?
- Does it avoid new root-only assumptions?
- Does it keep the writable surface limited to `/workspace` and `/home/agent`?
- Did the docs change if the security model changed?
