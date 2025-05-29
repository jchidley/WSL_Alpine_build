# PROJECT_WISDOM.md - WSL Alpine Build

## Critical Discoveries

### 2025-05-28: WSL [oobe] Section Not Supported in wsl.conf
Insight: WSL's wsl.conf does not recognize [oobe] configuration sections - this belongs in wsl-distribution.conf
Impact: First-boot setup configured via wsl-distribution.conf [oobe] section per Microsoft docs

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

### 2025-05-29: BATS Testing Requires Special Output Handling
Insight: BATS captures function output differently than normal execution - ANSI escape codes must be stripped for assertions
Impact: Test assertions should use sed to strip color codes: sed 's/\x1b\[[0-9;]*m//g' for reliable string matching

### 2025-05-29: Alpine-chroot-install Is Wrong Tool for WSL Distributions
Insight: alpine-chroot-install is designed for temporary CI/testing environments, not for building distributable images
Impact: Should use Alpine's official minirootfs tarballs instead - no bind mounts, no host risk, proper method for custom distributions

### 2025-05-29: WSL Tar Format - Microsoft Docs Are Wrong
Insight: Microsoft's docs recommend `--absolute-names` but this CAUSES import failures
Impact: Use `tar --numeric-owner -c .` WITHOUT --absolute-names flag, despite what MS documentation says

### 2025-05-29: WSL Import Requires Windows Paths in WSL 2
Insight: WSL --import fails with "ERROR_UNHANDLED_EXCEPTION" when using Linux paths for install location
Impact: Must use Windows paths (C:\WSL\<distro>) for install location and convert tar path with wslpath -w

### 2025-05-29: Root Ownership Critical for WSL Import
Insight: WSL requires all files in tar to be owned by root (0/0), not regular user (1000/1000)
Impact: Must use fakeroot when creating tar to preserve root ownership without needing sudo privileges

### 2025-05-29: Debugging WSL Import - Test Everything
Insight: Even vanilla Alpine minirootfs and exported WSL distributions failed with same error
Impact: The issue was with import parameters (paths) not the tar content - always test with known-good files first

### 2025-05-30: Modular Bash Libraries Enable Testability
Insight: Extracting common functions into sourced libraries (common.sh, prerequisites.sh) dramatically improves testing
Impact: Scripts become composable units - test individual functions in isolation, mock dependencies, achieve 100% coverage

### 2025-05-30: WSL Path Translation Error Has Simple Fix
Insight: WSL "Failed to translate" error when launching from another WSL can be fixed with --cd option
Impact: Use `wsl.exe -d <distro> --cd /` or `--cd ~` to bypass path translation entirely - no Windows Terminal needed