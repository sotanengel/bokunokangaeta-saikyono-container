# Security Policy

## Supported Scope

This repository provides a secure-by-default containerized workspace for AI-assisted development. Security-sensitive changes include:

- Container runtime flags
- Bind mount scope
- Network defaults
- Agent installation paths
- CI scanning behavior

## Reporting

If you discover a security issue, do not open a public issue with exploit details. Report it privately through your normal repository security channel before disclosure.

## Hardening Summary

- Non-root runtime user
- Read-only root filesystem at runtime
- All Linux capabilities dropped
- No new privileges
- Offline by default
- Separate CI lint, smoke, and security scans
