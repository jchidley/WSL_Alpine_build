# How to create and use a disposable Podman-first workspace

This guide shows the shortest path to build, use, and delete a target workspace.

## Prerequisites
- Running inside WSL
- Required tools installed (`wget`, `tar`, `gzip`, `fakeroot`, etc.)

## 1) Inspect target definition
Use the provided example target: `targets/podman-dev.yaml`

## 2) Build/import target workspace
```bash
./wsl-alpine up --target podman-dev
```

This creates/imports a WSL distro named `wslw-podman-dev`.

## 3) Open a shell in the workspace
```bash
./wsl-alpine shell podman-dev
```

## 4) Run one command without opening a shell
```bash
./wsl-alpine exec podman-dev -- podman info
```

## 5) Run directly from Windows (CMD/PowerShell)
From Windows terminal, run the distro directly:

```powershell
wsl.exe -d wslw-podman-dev
wsl.exe -d wslw-podman-dev -- podman info
```

## 6) Remove the workspace when done
```bash
./wsl-alpine down podman-dev --purge
```

## Optional cleanup of stale workspaces
```bash
./wsl-alpine gc
```
