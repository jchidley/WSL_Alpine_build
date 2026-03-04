# Safety Improvements for WSL Alpine Build

## Problem Summary

The alpine-chroot-install script mounts several host directories into the chroot:
- /dev
- /proc
- /sys
- /home (working directory)

If the script fails or is interrupted, these mounts can remain active, potentially corrupting the host system. In our case, /dev/null, /dev/random, and /dev/urandom were deleted when cleanup failed.

## Implemented Safeguards

### 1. Exit Trap for Cleanup
- Added `trap cleanup_on_exit EXIT` to ensure cleanup runs even if script fails
- Cleanup function attempts to unmount all chroot mounts
- Falls back to manual unmount if destroy script fails
- Recreates critical /dev devices if they're missing

### 2. Pre-flight System Checks
- Verifies /dev/null, /dev/random, /dev/urandom exist before starting
- Checks for existing mounts from previous failed runs
- Offers to clean up existing mounts before proceeding

### 3. Robust Mount Cleanup
- Primary: Uses alpine-chroot-install's destroy script
- Fallback: Manual unmount in reverse order
- Verification: Checks all mounts are removed
- Warning: Alerts user if manual cleanup needed

### 4. Build Process Improvements
- Better error handling around alpine-chroot-install execution
- Mount cleanup doesn't fail the entire build
- Clear progress indicators and error messages

## Usage Notes

The improved script will:
1. Check system integrity before starting
2. Detect and offer to clean up failed previous runs
3. Automatically clean up on any exit (success or failure)
4. Attempt to restore critical system devices if corrupted

## Emergency Recovery

If system corruption occurs despite safeguards:

```bash
# Recreate missing devices
sudo mknod -m 666 /dev/null c 1 3
sudo mknod -m 666 /dev/random c 1 8
sudo mknod -m 666 /dev/urandom c 1 9

# Check for stuck mounts
mount | grep "/tmp/alp"

# Unmount manually if needed
sudo umount -R /tmp/alp2/proc /tmp/alp2/sys /tmp/alp2/dev

# Remove chroot directory
sudo rm -rf /tmp/alp2
```

## Testing Recommendations

1. Test normal build completion
2. Test Ctrl+C interruption during build
3. Test script failure scenarios
4. Verify cleanup happens in all cases
5. Ensure /dev devices remain intact