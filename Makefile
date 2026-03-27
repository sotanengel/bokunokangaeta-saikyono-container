IMAGE ?= ai-agent-sandbox:latest
AGENT ?= shell

.PHONY: build shell shell-online compose-shell compose-shell-online doctor lint bootstrap-core bootstrap-polyglot install-agents install-host-tools-macos agent smoke

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

lint:
	./scripts/lint-local.sh

bootstrap-core:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- bootstrap-languages --core

bootstrap-polyglot:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- bootstrap-languages --polyglot

install-agents:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --online -- install-agents --all

install-host-tools-macos:
	./scripts/install-host-tools-macos.sh --write-shell-profile

agent:
	./scripts/run-sandbox.sh --image "$(IMAGE)" --agent "$(AGENT)"

smoke:
	IMAGE="$(IMAGE)" ./scripts/smoke-test.sh
