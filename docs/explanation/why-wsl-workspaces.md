# Why WSL workspaces instead of just containers?

This project is intentionally focused on **disposable WSL distributions**.

## What it is for
- Programmatic creation of minimal WSL2 environments
- Per-target workspaces you can create and destroy quickly
- Podman-first workflows inside the distro

## What it is not
- Not a replacement for Podman or container registries
- Not a full orchestration platform

## Why this can be useful
Containers are ideal for app/runtime packaging. A disposable WSL distro is useful when you want a full interactive Linux userland on Windows (shell/toolchain/system config) that is still throwaway and reproducible from a target spec.

## Overlap with Podman
There is intentional overlap in reproducibility goals. The split is:
- Podman: containerized app/runtime workflows
- This project: disposable developer workspace distributions
