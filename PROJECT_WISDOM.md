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