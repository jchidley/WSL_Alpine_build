# PROJECT_WISDOM.md - WSL Alpine Build

## Critical Discoveries

### 2025-05-28: WSL [oobe] Section Not Supported
Insight: WSL's wsl.conf does not recognize [oobe] configuration sections
Impact: First-boot setup must be triggered from shell profile instead

### 2025-05-28: WSL Import Requires Windows Paths
Insight: WSL --import command requires Windows-accessible paths, not Linux paths within WSL
Impact: Must create import directories under /mnt/c/Users/<username>/ and convert paths with wslpath

### 2025-05-28: Alpine Uses ash Shell by Default
Insight: Alpine Linux uses BusyBox ash shell, not bash, as its default shell
Impact: All scripts must use #!/bin/ash shebang and POSIX-compatible syntax

### 2025-05-28: $HOME Changes Under sudo
Insight: When scripts run with sudo, $HOME evaluates to /root instead of user's home
Impact: Must use ${SUDO_USER} to get real username and construct proper home path

### 2025-05-28: Code Duplication Creates Maintenance Burden
Insight: Test scripts that duplicate build logic lead to fixes being applied inconsistently
Impact: Refactored to have test script call main build script with test parameters

## Architecture Decisions

### Common Functions Pattern
- Extract shared logic to common-functions.sh
- All scripts source this file for consistency
- Single source of truth for critical operations

### Naming Convention
- All scripts follow pattern: wsl-alpine-{action}.sh
- Consistent, predictable naming improves discoverability

### 2025-05-29: WSL Archive Permission Issue with Sudo
Insight: When using sudo with output redirection (>), files are created with root ownership in root's context
Impact: Must use 'sudo tee' pattern and fix ownership, or files end up in /root instead of user's home

### 2025-05-29: WSL --list Output Encoding
Insight: WSL --list outputs UTF-16LE encoded text that breaks simple grep patterns
Impact: Must pipe through 'iconv -f UTF-16LE -t UTF-8' before processing with grep or other text tools

### 2025-05-29: Slash Commands are Documentation Templates
Insight: Claude Code slash commands (like /req) show documentation but don't execute automatically
Impact: Claude must implement the logic described in the command documentation, not expect automatic execution

### 2025-05-29: Alpine-chroot-install Bind Mounts Are Dangerous
Insight: alpine-chroot-install bind-mounts /dev, /proc, /sys which can corrupt host if cleanup fails
Impact: CRITICAL - Must use exit traps, multiple cleanup fallbacks, and system integrity checks to prevent catastrophic /dev corruption