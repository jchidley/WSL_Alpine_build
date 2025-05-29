.PHONY: test test-unit test-integration lint format debug clean install-deps help

# Default target
help:
	@echo "Alpine WSL Build - Testing and Development"
	@echo ""
	@echo "Available targets:"
	@echo "  make test           - Run all tests (lint + unit + integration)"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests"
	@echo "  make lint           - Run ShellCheck on all scripts"
	@echo "  make format         - Format code with shfmt"
	@echo "  make debug          - Run script in debug mode (dry-run)"
	@echo "  make clean          - Clean up test artifacts"
	@echo "  make install-deps   - Install test dependencies"

# Install test dependencies
install-deps:
	@echo "Installing test dependencies..."
	@which bats >/dev/null 2>&1 || (echo "Please install bats-core: https://github.com/bats-core/bats-core" && exit 1)
	@which shellcheck >/dev/null 2>&1 || (echo "Please install shellcheck: apt-get install shellcheck" && exit 1)
	@echo "All dependencies installed"

# Run all tests
test: lint test-unit test-integration

# Run unit tests
test-unit: install-deps
	@echo "Running unit tests..."
	@if [ -d "tests/unit" ] && ls tests/unit/*.bats >/dev/null 2>&1; then \
		bats tests/unit/*.bats; \
	else \
		echo "No unit tests found"; \
	fi

# Run integration tests
test-integration: install-deps
	@echo "Running integration tests..."
	@if [ -d "tests/integration" ] && ls tests/integration/*.bats >/dev/null 2>&1; then \
		bats tests/integration/*.bats; \
	else \
		echo "No integration tests found"; \
	fi

# Lint all shell scripts
lint: install-deps
	@echo "Running ShellCheck..."
	@find . -name "*.sh" -not -path "./tests/mocks/*" -not -path "./alpine-wsl-build/*" -exec shellcheck {} +

# Format code with shfmt (if available)
format:
	@if which shfmt >/dev/null 2>&1; then \
		echo "Formatting shell scripts..."; \
		find . -name "*.sh" -not -path "./tests/mocks/*" -not -path "./alpine-wsl-build/*" -exec shfmt -w {} +; \
	else \
		echo "shfmt not installed. Install with: GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt"; \
	fi

# Debug mode - dry run with verbose output
debug:
	DEBUG=1 VERBOSE=1 ./wsl-alpine-build-minirootfs.sh --dry-run --no-import

# Clean up test artifacts
clean:
	@echo "Cleaning up..."
	@rm -rf test-build-* alpine-wsl-build test-minimal/*.tar test-minimal/*.tar.gz
	@rm -f debug-*.log coverage.* .coverage
	@find . -name "*.tmp" -delete
	@echo "Cleanup complete"

# Run quick smoke test
smoke-test:
	@echo "Running smoke test..."
	./wsl-alpine-build-minirootfs.sh --help >/dev/null && echo "✓ Help works"
	@echo "Smoke test passed"