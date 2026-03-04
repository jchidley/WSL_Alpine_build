# Testing

This repo validates three things:
1. Script/library behavior (`./wsl-alpine test`)
2. Real image build/import flow (`./wsl-alpine build ...`)
3. Builder-distro parity (Debian vs Arch running the same build)

## 1) Standard test suite (fast, default)

```bash
./wsl-alpine test
```

Runs unit + integration tests for owned logic (CLI parsing, module wiring, WSL operations wrappers, packaging flow).

## 2) Real image build smoke test

Run in your active builder distro:

```bash
./wsl-alpine build --name alpine-test-smoke --modules base,pi-agent
wsl.exe -d alpine-test-smoke -- sh -lc "pi --version && rg --version && fd --version"
wsl.exe --terminate alpine-test-smoke
```

This verifies:
- import works via `wsl.exe`
- OOBE auto-finalization runs
- pi + core tooling are present in the resulting distro

## 3) Builder parity test (Debian + Arch)

Use identical module set and compare outcomes/timings.

### Debian builder
```bash
./wsl-alpine build --name alpine-build-deb --modules base,pi-agent
```

### Arch builder
```bash
# from Debian shell, invoke build inside archlinux distro
wsl.exe --cd /root/WSL_Alpine_build -d archlinux -- bash -lc "./wsl-alpine build --name alpine-build-arch --modules base,pi-agent"
```

### Validate both targets
```bash
wsl.exe -d alpine-build-deb  -- sh -lc "test -f /etc/oobe.done && pi --version"
wsl.exe -d alpine-build-arch -- sh -lc "test -f /etc/oobe.done && pi --version"
```

## Cleanup

```bash
wsl.exe --unregister alpine-test-smoke
wsl.exe --unregister alpine-build-deb
wsl.exe --unregister alpine-build-arch
```

## Notes
- Prefer `wsl.exe` in docs/examples for CMD/PowerShell parity.
- Keep active repo work on `~/...` (ext4), not `/mnt/c/...`.
- `base,pi-agent` is the default fast build profile.
