IMAGE ?= ai-agent-sandbox:latest
AGENT ?= shell
POLYGLOT_GROUP ?= all
AGENT_SMOKE ?= all
EXPORT_DIR ?= dist/image-artifacts

.PHONY: build shell shell-online compose-shell compose-shell-online doctor doctor-host audit-host-security lint pre-commit install-pre-commit-hook bootstrap-core bootstrap-polyglot polyglot-smoke install-agents agent-smoke install-host-tools-macos install-host-tools-linux start-podman-machine-macos repair-podman-machine-macos export-image-artifacts agent smoke

build:
	./scripts/build-image.sh --image "$(IMAGE)"

shell:
	./scripts/run-sandbox.sh --image "$(IMAGE)"

shell-online:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online

compose-shell:
	./scripts/compose-shell.sh

compose-shell-online:
	./scripts/compose-shell.sh --online

doctor:
	./scripts/check-prereqs.sh

doctor-host:
	./scripts/check-container-engines.sh

audit-host-security:
	./scripts/audit-host-security.sh

lint:
	./scripts/lint-local.sh

pre-commit:
	./scripts/run-pre-commit.sh

install-pre-commit-hook:
	./scripts/run-pre-commit.sh install

bootstrap-core:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- bootstrap-languages --core

bootstrap-polyglot:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- bootstrap-languages --polyglot

polyglot-smoke:
	./scripts/polyglot-smoke-test.sh --image "$(IMAGE)" --group "$(POLYGLOT_GROUP)"

install-agents:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- install-agents --all

agent-smoke:
	./scripts/agent-smoke-test.sh --image "$(IMAGE)" --agent "$(AGENT_SMOKE)"

install-host-tools-macos:
	./scripts/install-host-tools-macos.sh --write-shell-profile

install-host-tools-linux:
	./scripts/install-host-tools-linux.sh

start-podman-machine-macos:
	./scripts/start-podman-machine-macos.sh

repair-podman-machine-macos:
	./scripts/repair-podman-machine-macos.sh

agent:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --agent "$(AGENT)"

smoke:
	IMAGE="$(IMAGE)" ./scripts/smoke-test.sh

export-image-artifacts:
	./scripts/export-image-artifacts.sh --image "$(IMAGE)" --output-dir "$(EXPORT_DIR)"
