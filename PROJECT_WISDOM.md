# PROJECT_WISDOM.md - WSL Alpine Build

*Note: Older insights archived to PROJECT_WISDOM_ARCHIVE_20250530.md*

## Active Insights (Recent & Critical)

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

### 2025-05-30: Alpine Shell Compatibility - Use ash Not bash
Insight: Alpine's default shell is ash (BusyBox), not bash - using bash breaks Alpine's minimalist philosophy
Impact: Use /bin/ash for user shells, .profile instead of .bashrc, and ensure all scripts are POSIX-compatible

### 2025-05-30: Alpine Package Availability - Not All tree-sitter Parsers Exist
Insight: tree-sitter-comment and tree-sitter-ini packages don't exist in Alpine repositories (v3.18)
Impact: Must verify package existence before adding to build scripts - check pkgs.alpinelinux.org for availability

### 2025-05-30: Alpine BusyBox passwd Has Hardcoded Password Policies
Insight: BusyBox passwd enforces strict password rules that can't be configured via login.defs or PAM
Impact: Install shadow package to get configurable passwd command, or prompt user for password during installation

### 2025-05-30: Pre-installed Scripts Improve User Experience
Insight: Including utility scripts like install-claude-code in /usr/local/bin eliminates manual copy steps
Impact: Users can immediately run helpful commands after login without additional setup or documentation lookup

### 2025-05-30: Document Failures Comprehensively to Prevent Repetition
Insight: Every failure teaches valuable lessons - documenting them prevents future developers from repeating mistakes
Impact: Updated MINIROOTFS-APPROACH.md with 8 major failure categories including tree-sitter, Docker/OpenRC, and Claude Code challenges

### 2025-05-30: Modular Integration Beats Monolithic Changes
Insight: Created separate modules (claude-code-oobe.sh) that can be mixed into builds rather than duplicating entire scripts
Impact: Maintainable approach - one module can enhance multiple build scripts without code duplication

### 2025-01-30: Comprehensive Refactoring Enables Safe, Modular Architecture
Insight: Replacing 22 scripts with a single entry point and modular libraries dramatically improves maintainability and safety
Impact: No more dangerous chroot operations, full test coverage, and users can pick exactly the features they need through modules

### 2025-01-31: Test What You Own, Not What You Use
Insight: Tests that verify OS commands work (mktemp, rm, tar) are meaningless - focus on testing YOUR validation/error handling logic
Impact: Reduced test suite from 106 to 71 tests by removing OS behavior tests, now 95% pass rate with only mock limitations failing

### 2025-01-31: Empty Skipped Tests Are Worse Than No Tests
Insight: Having 12 placeholder "skip" tests creates confusion and false sense of incomplete coverage - better to remove them entirely.
Impact: Achieved 0 skipped tests in default run by removing empty tests and separating real environment tests with explicit flag.

### 2025-01-31: Test Only What Matters - Alpine Always Uses OpenRC
Insight: Testing systemd configuration when Alpine exclusively uses OpenRC is pointless - remove unused code paths from tests
Impact: Removed systemd=true test but kept OpenRC boot command test as it's essential for services like Docker to start properly

### 2025-05-31: Alpine Uses Ash Shell, Not Bash
Insight: Alpine Linux uses BusyBox ash as its default shell - assuming /bin/bash breaks WSL startup
Impact: Updated all shell references from /bin/bash to /bin/ash, use .ashrc instead of .bashrc for shell configuration

### 2025-05-31: Package Installation Must Happen Inside WSL
Insight: Running APK commands via chroot during build fails due to permission issues - use OOBE scripts instead
Impact: Moved all package installations to /etc/oobe.d/ scripts that run on first boot with proper permissions

### 2025-05-31: Log Output Must Go to Stderr for Command Substitution
Insight: When capturing function output with $(), all stdout is captured including log messages - breaks command substitution
Impact: Redirected all logging functions to stderr (>&2) to allow clean output capture while maintaining visible logs