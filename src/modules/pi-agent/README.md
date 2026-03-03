# pi-agent Module

Installs the pi coding agent CLI used in this environment.

## Includes
- Node.js (`nodejs-current`) + npm + direnv from Alpine repositories
- Shell/search tooling used by pi workflows: `bash`, `ripgrep` (`rg`), `fd`
- Global install of `@mariozechner/pi-coding-agent`
- Debian key bridge command: `debian-ak-export`
- Shell function: `load-api-keys` (evals exports from Debian `ak`)
- Default pi settings at `~/.pi/agent/settings.json`:
  - `defaultProvider: openai`
  - `defaultModel: gpt-5.3-codex`
  - `defaultThinkingLevel: medium`

## Commands
- `install-pi-agent` to install/reinstall the CLI
  - Uses Alpine packages (`nodejs-current` + `npm`) for runtime dependencies
  - Installs prerequisites automatically if missing
  - Works as root or via sudo when package install is required
- `debian-ak-export`
  - Calls Debian's `ak export` via `wsl.exe`
  - Keeps API key source of truth in Debian only
- `load-api-keys`
  - Convenience shell function to import all keys into current shell
- `direnv` is auto-hooked via `/etc/profile.d/pi-agent-env.sh`
