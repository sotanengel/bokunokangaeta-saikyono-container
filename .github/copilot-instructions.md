# GitHub Copilot Instructions

- Read `AGENTS.md` before proposing edits.
- Keep this repository OCI-compatible and Podman/Docker-friendly.
- Prefer `scripts/run-sandbox.sh` over ad-hoc container invocations.
- Default to offline execution. Only enable network for explicit bootstrap work.
- Preserve the runtime security flags and update docs when changing them.
- Use a separate branch per implementation. Do not mix unrelated changes into one branch or PR.
- Follow `.github/pull_request_template.md` when drafting a pull request description.
