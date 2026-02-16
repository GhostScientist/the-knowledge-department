SHELL := /usr/bin/env bash

.PHONY: help install enable enable-all status smoke smoke-online check scaffold-check

help:
	@echo "TKD developer commands"
	@echo ""
	@echo "  make install       Install knowledge CLI to ~/.tkd/bin"
	@echo "  make enable        Enable repo hooks for Claude only"
	@echo "  make enable-all    Enable repo hooks for all configured agents"
	@echo "  make status        Print hook integration status for this repo"
	@echo "  make smoke         Run offline smoke test"
	@echo "  make smoke-online  Run online smoke test (requires local port binding)"
	@echo "  make check         Run script syntax checks"
	@echo "  make scaffold-check Verify phase-2 scaffold files exist"

install:
	./scripts/install-tkd-agent.sh

enable:
	~/.tkd/bin/knowledge enable --agent claude --force

enable-all:
	~/.tkd/bin/knowledge enable --all-agents --force

status:
	~/.tkd/bin/knowledge status

smoke:
	./scripts/smoke-test.sh

smoke-online:
	./scripts/smoke-test.sh --online

check:
	bash -n scripts/knowledge.sh
	bash -n scripts/install-tkd-agent.sh
	bash -n scripts/smoke-test.sh
	python3 -m py_compile scripts/mock_tkd_server.py

scaffold-check:
	test -f services/tkd-api/README.md
	test -f services/tkd-api/api/openapi.yaml
	test -f agents/custodians/README.md
	test -f research/watership/README.md
	test -f research/watership/scenarios/engineering-api-naming-conflict.json
	test -f research/evals/README.md
	test -f contracts/tkd.event.v0.schema.json
