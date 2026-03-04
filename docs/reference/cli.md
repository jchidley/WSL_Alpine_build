# CLI Reference

## Core commands

```bash
./wsl-alpine help
./wsl-alpine build [options]
./wsl-alpine install [--name <name>] <archive.tar.gz>
./wsl-alpine module list
./wsl-alpine module info <module>
./wsl-alpine list
./wsl-alpine reset <name>
./wsl-alpine test
./wsl-alpine test-smoke [--name <name>] [--modules <list>] [--keep]
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

Default (fast path):

```bash
./wsl-alpine build
# modules: base,pi-agent
```

Use all modules:

```bash
./wsl-alpine build --modules all
```
