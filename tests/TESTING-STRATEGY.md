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

## Builder parity (manual validation)

Builder-distro parity (Debian vs Arch) is validated as a real smoke check, not in default BATS:

```bash
./wsl-alpine test-smoke --name alpine-validate-deb --modules base,pi-agent --keep
wsl.exe --cd /root/WSL_Alpine_build -d archlinux -- bash -lc "./wsl-alpine test-smoke --name alpine-validate-arch --modules base,pi-agent --keep"

wsl.exe -d alpine-validate-deb  -- sh -lc "pi --version && test -f /etc/oobe.done"
wsl.exe -d alpine-validate-arch -- sh -lc "pi --version && test -f /etc/oobe.done"
```

## Notes

- Keep tests fast and deterministic.
- Prefer mocks/stubs over network/system-heavy checks in default test runs.
- Keep real builder/image smoke checks documented and repeatable with `wsl.exe` commands.
