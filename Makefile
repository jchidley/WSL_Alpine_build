.PHONY: help test lint clean smoke-test

help:
	@echo "WSL Alpine Build"
	@echo ""
	@echo "Targets:"
	@echo "  make test        - Run standard test suite (./wsl-alpine test)"
	@echo "  make smoke-test  - Run real smoke build/import/verify (./wsl-alpine test-smoke)"
	@echo "  make lint        - Run shellcheck on active scripts"
	@echo "  make clean       - Remove temporary local artifacts"

test:
	./wsl-alpine test

smoke-test:
	./wsl-alpine test-smoke

lint:
	@which shellcheck >/dev/null 2>&1 || (echo "Install shellcheck first" && exit 1)
	shellcheck wsl-alpine src/lib/*.sh src/modules/*/install.sh

clean:
	rm -rf /tmp/alpine-wsl-build
