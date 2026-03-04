# Testing Strategy

## Overview

The suite follows: **test what we own, not what we use**.

## Test Categories

### 1) Unit tests (`tests/unit/`)
- Function-level behavior and validation.

### 2) Integration tests (`tests/integration/`)
- CLI behavior and internal workflow coordination.
- No special "real environment" mode.

## Running tests

```bash
./wsl-alpine test
```

This runs the standard unit + integration suite.

## Direct BATS usage

```bash
bats tests/unit/*.bats
bats tests/integration/test_build_workflow.bats \
     tests/integration/test_modular_build.bats \
     tests/integration/test_build_validation.bats
```

## Notes

- Keep tests fast and deterministic.
- Prefer mocks/stubs over network/system-heavy checks.
- Add integration tests only for user-facing behavior changes.
