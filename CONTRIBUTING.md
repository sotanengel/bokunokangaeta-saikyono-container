# Contributing

## Principles

- Keep the runtime secure by default.
- Preserve Podman and Docker compatibility.
- Do not widen mounts, privileges, or network access without updating docs.
- Keep start/finish audit logging intact for both `run-sandbox` and Compose paths.
- Keep agent-specific files aligned with `AGENTS.md`.

## Local Checks

```bash
./scripts/install-host-tools-macos.sh --write-shell-profile
./scripts/check-prereqs.sh
./scripts/check-container-engines.sh
./scripts/audit-host-security.sh
./scripts/lint-local.sh
make build
make smoke
make polyglot-smoke POLYGLOT_GROUP=core
make agent-smoke AGENT_SMOKE=copilot
```

## Review Checklist

- Does the change keep offline-by-default behavior?
- Does it avoid new root-only assumptions?
- Does it keep the writable surface limited to `/workspace` and `/home/agent`?
- Does it preserve host-side audit logs and high-risk workspace mount rejection?
- Does it keep CI smoke coverage for languages and supported agents coherent?
- Did the docs change if the security model changed?
