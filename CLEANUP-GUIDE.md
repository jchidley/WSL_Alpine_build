# WSL Alpine Cleanup Guide

This guide provides comprehensive instructions for cleaning up Alpine WSL installations, including automated scripts and manual steps when needed.

## Automated Cleanup Scripts

### 1. Standard Cleanup (`wsl-alpine-cleanup.sh`)
Use this for cleaning up normal Alpine installations:
```bash
# With sudo to preserve PATH
sudo ./wsl-alpine-cleanup.sh

# Or specify a distribution name
sudo ./wsl-alpine-cleanup.sh alp2
```

### 2. Reset Script (`wsl-alpine-reset.sh`)
Quick cleanup for the default distribution:
```bash
sudo ./wsl-alpine-reset.sh
```

### 3. Test Cleanup (`wsl-alpine-test-cleanup.sh`)
Remove all test distributions (alp-test-*):
```bash
sudo ./wsl-alpine-test-cleanup.sh
```

## What Gets Cleaned

### WSL Components
- WSL distribution registration
- Virtual disk files stored by Windows
- Distribution metadata

### File System Components
- `/tmp/{distribution-name}` - Chroot build directory
- `~/alpine.wsl.gz` - Distribution archive
- `./alpine-chroot-install` - Build script

## Manual Cleanup Steps

### 1. If Scripts Fail with Permission Errors

**In Windows Terminal (as Administrator):**
```powershell
# List all distributions
wsl --list --verbose

# Unregister specific distribution
wsl --unregister alp2

# Or force terminate first
wsl --terminate alp2
wsl --unregister alp2
```

### 2. Remove Chroot Directories

**In WSL:**
```bash
# Check what's in /tmp
ls -la /tmp/alp*

# Remove with sudo
sudo rm -rf /tmp/alp2
sudo rm -rf /tmp/alp-test-*
```

### 3. Clean Distribution Archives
```bash
rm -f ~/alpine.wsl.gz
rm -f ~/alpine-test.wsl.gz
```

### 4. Windows File System Cleanup

WSL stores distribution data in Windows AppData. To fully clean:

1. Open File Explorer
2. Navigate to: `%LOCALAPPDATA%\Packages`
3. Look for folders starting with `CanonicalGroupLimited`
4. Find and delete the specific distribution folder

**Or use PowerShell:**
```powershell
# View WSL package data
Get-ChildItem "$env:LOCALAPPDATA\Packages" | Where-Object {$_.Name -like "*CanonicalGroupLimited*"}
```

## Common Issues and Solutions

### Issue: "Access Denied" when unregistering
**Solution:** Run Windows Terminal as Administrator

### Issue: "Distribution is currently running"
**Solution:** 
```bash
wsl --terminate distribution-name
# Then retry unregister
```

### Issue: Chroot directory won't delete
**Solution:** Check for mounted filesystems
```bash
# Check mounts
mount | grep /tmp/alp

# If found, unmount first
sudo umount /tmp/alp2/proc
sudo umount /tmp/alp2/sys
sudo umount /tmp/alp2/dev
# Then remove directory
sudo rm -rf /tmp/alp2
```

### Issue: Script can't find wsl.exe
**Solution:** The scripts now automatically add Windows paths. If it still fails:
```bash
# Run with preserved environment
sudo -E ./cleanup-script.sh
```

## Verification

After cleanup, verify everything is removed:

```bash
# Check WSL distributions
wsl --list

# Check for leftover files
ls -la /tmp/alp*
ls -la ~/alpine*.wsl.gz

# Check running processes
ps aux | grep -i alpine
```

## Prevention Tips

1. **Use test distributions** for experiments:
   ```bash
   ./wsl-alpine-test.sh
   ```

2. **Document your distributions** - keep track of what you create

3. **Regular cleanup** - don't let test distributions accumulate

4. **Use the cleanup scripts** - they handle most edge cases

## Emergency Recovery

If WSL becomes corrupted:

1. **Reset WSL entirely** (last resort):
   ```powershell
   # In PowerShell as Administrator
   wsl --shutdown
   # Then in Settings > Apps > Apps & features
   # Find "Windows Subsystem for Linux" and click "Advanced options" > "Reset"
   ```

2. **Reinstall specific distribution**:
   ```bash
   # First clean up
   sudo ./wsl-alpine-cleanup.sh
   # Then rebuild
   sudo ./wsl-alpine-build.sh
   ```

## Getting Help

If cleanup fails:
1. Check the error messages carefully
2. Run with `-x` for debug output: `bash -x ./cleanup-script.sh`
3. Check Windows Event Viewer for WSL errors
4. Verify WSL service is running: `wsl --status`