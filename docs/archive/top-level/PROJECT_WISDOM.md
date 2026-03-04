# PROJECT_WISDOM.md - WSL Alpine Build

*Note: Older insights archived to PROJECT_WISDOM_ARCHIVE_20250601.md*

## Active Insights (Recent & Critical)

### 2025-05-30: Modular Bash Libraries Enable Testability
Insight: Extracting common functions into sourced libraries (common.sh, prerequisites.sh) dramatically improves testing
Impact: Scripts become composable units - test individual functions in isolation, mock dependencies, achieve 100% coverage

### 2025-05-30: WSL Path Translation Error Has Simple Fix
Insight: WSL "Failed to translate" error when launching from another WSL can be fixed with --cd option
Impact: Use `wsl.exe -d <distro> --cd /` or `--cd ~` to bypass path translation entirely - no Windows Terminal needed

### 2025-05-30: Alpine Shell Compatibility - Use ash Not bash
Insight: Alpine's default shell is ash (BusyBox), not bash - using bash breaks Alpine's minimalist philosophy
Impact: Use /bin/ash for user shells, .profile instead of .bashrc, and ensure all scripts are POSIX-compatible

### 2025-05-31: Package Installation Must Happen Inside WSL
Insight: Running APK commands via chroot during build fails due to permission issues - use OOBE scripts instead
Impact: Moved all package installations to /etc/oobe.d/ scripts that run on first boot with proper permissions

### 2025-05-31: Log Output Must Go to Stderr for Command Substitution
Insight: When capturing function output with $(), all stdout is captured including log messages - breaks command substitution
Impact: Redirected all logging functions to stderr (>&2) to allow clean output capture while maintaining visible logs

### 2025-05-31: Test Suite Must Validate Correctness, Not Just Execution
Insight: Tests passing with DRY_RUN=1 only verify code runs without errors, not that it produces correct output
Impact: Added validation tests that check actual build artifacts - shell paths, OOBE scripts, no chroot operations

### 2025-05-31: Minimal Package Philosophy Lost in Modular Refactoring
Insight: Original minimal design (7 packages) expanded to 24+ packages during modularization - defeats Alpine's minimalist purpose
Impact: Must reduce packages back to essentials: helix fd bat zoxide fzf ripgrep tree - everything else is bloat

### 2025-05-31: All Modules Must Use OOBE for Package Installation
Insight: Only base module was migrated to OOBE approach - other modules still used chroot causing permission failures
Impact: Migrated development, docker, and claude-code modules to use OOBE scripts for consistent, permission-safe installation