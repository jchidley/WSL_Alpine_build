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
| Build distro (default modules) | `./wsl-alpine build --name <name>` |
| Build distro (explicit modules) | `./wsl-alpine build --name <name> --modules base,pi-agent` |
| Build all modules | `./wsl-alpine build --modules all` |
| Import existing archive | `./wsl-alpine install --name <name> <archive.tar.gz>` |
| Workspace up from target | `./wsl-alpine up --target <target-or-file>` |
| Open shell in target | `./wsl-alpine shell <target>` |
| Run command in target | `./wsl-alpine exec <target> -- <cmd...>` |
| Stop/remove target | `./wsl-alpine down <target> --purge` |
| Cleanup old targets | `./wsl-alpine gc` |
| List modules | `./wsl-alpine module list` |
| Module info | `./wsl-alpine module info <module>` |
| Run standard tests | `./wsl-alpine test` |
| Run real smoke test | `./wsl-alpine test-smoke` |

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

## From-scratch workflow notes
- A fresh Windows setup still requires one Linux **builder distro** (e.g. `Debian` or `archlinux`) to run `./wsl-alpine ...`.
- Do not assume `wsl.exe --install -d Alpine` exists in the online catalog.
- For timing comparisons across builders: use identical modules (`base,pi-agent`), run `wsl.exe --shutdown` between runs, and compare wall-clock times only.

## Documentation discipline
- Human-facing docs (`docs/how-to/*`, README, explanations): follow Diátaxis (use human-docs skill).
- Agent context files (`AGENTS.md`, `CLAUDE.md`, `SKILL.md`): keep concise, command-first, execution-focused (use llm-docs skill).
