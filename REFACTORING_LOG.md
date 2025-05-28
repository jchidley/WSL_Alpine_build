# REFACTORING_LOG.md - WSL Alpine Build Script Refactoring

## Session 2025-05-28: Major Script Refactoring and Bug Fixes

### Key Accomplishments
- Fixed automatic first-boot setup (oobe.sh) to run without manual intervention
- Discovered WSL doesn't support [oobe] section in wsl.conf
- Refactored all scripts to eliminate code duplication
- Renamed scripts for consistency: wsl-alpine-{build,reset,test,test-cleanup}.sh
- Extracted common logic to common-functions.sh
- Fixed WSL import issues with proper Windows path handling

### Git Activity
```
Staged renames:
- reset-wsl-alpine-build.sh -> wsl-alpine-reset.sh
- wsl-alpine-build-test-cleanup.sh -> wsl-alpine-test-cleanup.sh
- test-wsl-alpine-build.sh -> wsl-alpine-test.sh

Modified files pending commit:
- All documentation updated with new script names
- common-functions.sh expanded with shared logic
- All scripts updated to use common functions
- PROJECT_WISDOM.md created with technical discoveries
```

### Discoveries
- **WSL [oobe] Not Supported**: WSL's wsl.conf doesn't recognize [oobe] sections. Solution: Run first-boot setup from /root/.profile instead
- **WSL Import Path Requirements**: WSL --import requires Windows-accessible paths under /mnt/c/Users/<username>/. Linux paths within WSL cause "unhandled exception" errors
- **Alpine Shell Differences**: Alpine uses ash (BusyBox) by default, not bash. All scripts must use #!/bin/ash and POSIX syntax
- **sudo $HOME Issue**: When running with sudo, $HOME evaluates to /root. Must use ${SUDO_USER} to get real user

### Technical Details

#### Common Functions Extracted
```bash
# Path handling
get_real_home()           # Gets actual user home when running with sudo
get_windows_username()    # Extracts Windows username via cmd.exe
get_windows_path()        # Converts Linux paths to Windows format

# WSL operations
create_wsl_install_dir()  # Creates proper Windows-accessible directory
import_wsl_distribution() # Handles WSL import with path conversion
cleanup_wsl_dirs()        # Removes all possible WSL directories
```

#### First-Boot Setup Fix
Changed from non-functional wsl.conf [oobe] section to shell profile:
```bash
# In /root/.profile
if [ -f /etc/oobe.sh ] && [ ! -f /etc/oobe.done ]; then
    /etc/oobe.sh
fi
```

#### Test Script Refactoring
Old: Duplicated entire build logic
New: Creates test .env file and calls main build script

### Next Session Priority
- Commit all refactored scripts with proper commit message
- Test the refactored scripts end-to-end
- Consider adding automated tests for common functions

---
## Key Commands

```bash
# Test the build with a unique test distribution
sudo ./wsl-alpine-test.sh

# Clean up test distributions
sudo ./wsl-alpine-test-cleanup.sh

# Reset/remove a distribution completely
sudo ./wsl-alpine-reset.sh

# Build the main distribution
sudo ./wsl-alpine-build.sh
```