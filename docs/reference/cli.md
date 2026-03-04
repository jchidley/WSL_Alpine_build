# CLI Reference

## Core commands

```bash
./wsl-alpine help
./wsl-alpine build [options]
./wsl-alpine module list
./wsl-alpine module info <module>
./wsl-alpine list
./wsl-alpine reset <name>
./wsl-alpine test
```

## Disposable workspace commands

```bash
./wsl-alpine up --target <name|file> [--rebuild]
./wsl-alpine shell <target>
./wsl-alpine exec <target> -- <command...>
./wsl-alpine down <target> [--purge]
./wsl-alpine gc
```

## Build modules
Current modules:
- `base`
- `podman`
- `pi-agent`
- `development`

Use all modules:

```bash
./wsl-alpine build --modules all
```
