# AGENTS.md

## Source of truth
- This file is the authoritative agent context for this repo.
- `CLAUDE.md` should only point here.

## Project goal
Build **minimal, disposable Alpine WSL2 environments** with a **Podman-first** workflow.

## Runtime requirement
- Built workspaces/distros must be runnable directly from **Windows CMD/PowerShell** using `wsl.exe` (not Linux-only wrappers).

## Primary commands
| Task | Command |
|---|---|
| Show help | `./wsl-alpine help` |
| Build distro | `./wsl-alpine build --name <name> --modules base,podman,pi-agent,development` |
| Build all modules | `./wsl-alpine build --modules all` |
| Workspace up from target | `./wsl-alpine up --target <target-or-file>` |
| Open shell in target | `./wsl-alpine shell <target>` |
| Run command in target | `./wsl-alpine exec <target> -- <cmd...>` |
| Stop/remove target | `./wsl-alpine down <target> --purge` |
| Cleanup old targets | `./wsl-alpine gc` |
| List modules | `./wsl-alpine module list` |
| Module info | `./wsl-alpine module info <module>` |
| Run all tests | `./wsl-alpine test` |
| Unit tests only | `./wsl-alpine test --unit` |

## Modules (current)
- `base` (required)
- `podman` (container runtime)
- `pi-agent` (pi coding agent CLI)
- `development`

## Boundaries
- Do not reintroduce Docker/claude-code modules unless explicitly requested.
- Keep active Linux work on ext4 paths (`~/...`), not `/mnt/c/...`.
- Prefer minimal/surgical edits; preserve existing test behavior.
- Ask before destructive cleanup outside managed target state.

## Validation requirements
- After code changes: run `./wsl-alpine test` (or at least impacted subset + explain why).
- For shell script edits: ensure syntax validity (`bash -n <file>` when relevant).

## Known environment constraints (WSL)
- `xdg-open` does not work; use Windows-side tools when needed.
- Filesystem operations on `/mnt/c` are slower and less reliable for watch-heavy workflows.
