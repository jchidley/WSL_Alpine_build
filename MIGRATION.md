# Migration Guide

This project now uses a single entrypoint: `./wsl-alpine`.

## Command mapping (legacy -> current)

| Legacy | Current |
|---|---|
| `./wsl-alpine-build.sh` | `./wsl-alpine build` |
| `./wsl-alpine-reset.sh` | `./wsl-alpine reset <name>` |
| `./wsl-alpine-test.sh` | `./wsl-alpine test` |
| `./wsl-alpine-test-cleanup.sh` | `wsl.exe --unregister <name>` (targeted) |

## Current module set

- `base` (required)
- `pi-agent`
- `podman`
- `development`

Default build profile is now optimized for speed:

```bash
./wsl-alpine build
# equivalent to: ./wsl-alpine build --modules base,pi-agent
```

## Typical migration flow

1) Build new distro
```bash
./wsl-alpine build --name alpine-new --modules base,pi-agent
```

2) Verify from Windows-compatible command path
```powershell
wsl.exe -d alpine-new -- sh -lc "pi --version"
```

3) Optional data copy from old distro
```powershell
wsl.exe -d old-distro -- tar -cf - /home/user/data | wsl.exe -d alpine-new -- tar -xf - -C /
```

4) Remove old distro when satisfied
```bash
./wsl-alpine reset old-distro
```

## Important behavior changes

- Import finalization is automatic: after `build`/`install`, `/etc/oobe.sh` is run as root and distro is terminated once.
- Day-to-day runtime commands should use `wsl.exe` directly from CMD/PowerShell.
- Test command is simplified to one standard suite:
  - `./wsl-alpine test`

## Deprecated artifacts

Legacy scripts remain under `legacy/` for historical reference only and are not part of the active workflow.
