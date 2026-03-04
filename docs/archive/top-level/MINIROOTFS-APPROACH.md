# Building Alpine Linux for WSL using MinirootFS

## Quick Reference - Critical Requirements

**These four requirements MUST be met for successful WSL import:**

1. **Use `fakeroot`** - Preserve root ownership (0/0) without sudo
2. **Use Windows paths** - `C:\WSL\...` for install location (NOT Linux paths)
3. **Use `tar -c .`** - NOT `tar -c *` (proper directory structure)
4. **No `--absolute-names`** - Despite Microsoft docs, this flag breaks imports

## Current Working Solution

### Prerequisites
- Linux environment (WSL, VM, or native)
- Tools: `wget`, `tar`, `gzip`, `sha256sum`, `fakeroot`
- Access to `wsl.exe` command

### Step 1: Download Alpine MinirootFS
```bash
ALPINE_VERSION="3.18.6"
ARCH="x86_64"
BUILD_DIR="alpine-wsl-build"

mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
sha256sum -c "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
```

### Step 2: Extract and Configure
```bash
ROOTFS_DIR="rootfs"
mkdir -p "$ROOTFS_DIR"
tar -xzf "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz" -C "$ROOTFS_DIR"

cd "$ROOTFS_DIR"

# Configure APK repositories
cat > etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/v3.18/main
https://dl-cdn.alpinelinux.org/alpine/v3.18/community
EOF

# Create WSL configuration
cat > etc/wsl.conf << 'EOF'
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[boot]
systemd = false
EOF

# Create OOBE script (first-boot setup)
cat > etc/oobe.sh << 'EOF'
#!/bin/sh
[ -f /etc/oobe.done ] && exit 0

echo "Alpine WSL: Running first-time setup..."

# Update and install packages
apk update
apk add --no-cache alpine-base openrc util-linux sudo bash shadow
apk add --no-cache git curl wget openssh-client build-base
apk add --no-cache helix fd bat zoxide fzf ripgrep tree
apk add --no-cache docker docker-cli-compose

# Create default user (UID 1000)
adduser -D -u 1000 -s /bin/bash -h /home/wsluser -g "WSL User" wsluser
echo "wsluser:wsluser" | chpasswd
addgroup wsluser wheel
addgroup wsluser docker

# Configure sudo
echo "wsluser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wsluser
chmod 440 /etc/sudoers.d/wsluser

# Update wsl.conf with default user
echo -e "\n[user]\ndefault = wsluser" >> /etc/wsl.conf

# Clean up
rm -rf /var/cache/apk/*
touch /etc/oobe.done

echo "Setup complete! Please restart the distribution."
EOF
chmod +x etc/oobe.sh

# Essential directories and cleanup
mkdir -p proc sys dev tmp
chmod 1777 tmp
rm -f etc/resolv.conf  # Let WSL generate this

cd ..
```

### Step 3: Package with Fakeroot
```bash
# Create packaging script for fakeroot
cat > package.sh << 'SCRIPT'
#!/bin/bash
set -e
cd "$1"
tar --numeric-owner -c . | gzip --fast > ../alpine-wsl.tar.gz
SCRIPT
chmod +x package.sh

# Package with fakeroot to preserve root ownership
fakeroot -- ./package.sh "$ROOTFS_DIR"

# Verify ownership (MUST show 0/0)
tar -tvf alpine-wsl.tar.gz | head -5
```

### Step 4: Import into WSL
```bash
DISTRO_NAME="alpine-wsl"

# Convert tar path to Windows format
WIN_TAR_PATH=$(wslpath -w alpine-wsl.tar.gz)

# Import with Windows path for install location
wsl.exe --import "$DISTRO_NAME" "C:\\WSL\\$DISTRO_NAME" "$WIN_TAR_PATH" --version 2

# Launch (triggers OOBE on first boot)
wsl.exe -d "$DISTRO_NAME"
```

## What Failed and Why

### 1. ERROR_UNHANDLED_EXCEPTION Failures

**Tar Format Failures:**
- `tar --numeric-owner --absolute-names -c *` - **FAILED** (Microsoft docs are wrong)
- `tar --numeric-owner -c *` - **FAILED** (missing directory structure)
- `tar -c *` - **FAILED** (wrong ownership and structure)
- **ONLY WORKED:** `tar --numeric-owner -c .` with fakeroot

**Path Format Failures:**
- `/tmp/wsl-alpine-install` - **FAILED** (Linux path)
- `./wsl-test-install` - **FAILED** (relative path)
- `/home/user/alpine` - **FAILED** (Linux path)
- **ONLY WORKED:** `C:\WSL\alpine-test` (Windows path)

**Ownership Failures:**
- Regular user tar extraction - **FAILED** (1000/1000 ownership)
- sudo tar without numeric-owner - **FAILED** (symbolic names)
- **ONLY WORKED:** fakeroot with --numeric-owner (0/0 ownership)

### 2. Package Installation Failures

**Tree-sitter Packages (Alpine 3.18):**
```bash
# These packages don't exist in Alpine 3.18
tree-sitter-markdown@testing  # FAILED - not found
tree-sitter-css              # FAILED - not found
tree-sitter-javascript       # FAILED - not found
# Resolution: Removed all tree-sitter packages
```

**Node.js During Build:**
```bash
# Attempting npm install in chroot - FAILED
# No network access in build environment
# Resolution: Moved to OOBE script
```

### 3. Service Management Failures

**Docker Service:**
```bash
service docker start         # FAILED - Alpine uses OpenRC not systemd
rc-service docker start      # FAILED - OpenRC not initialized
/etc/init.d/docker start     # FAILED - missing runtime directory

# Working solution:
mkdir -p /run/openrc && touch /run/openrc/softlevel
rc-service docker start
# Or manually: dockerd > /dev/null 2>&1 &
```

### 4. WSL Interop Failures

**Cross-Distribution Commands:**
```bash
# From Debian WSL running Alpine commands
wsl.exe -d alpine-test      # FAILED - path context issues
wsl.exe -d alpine-test pwd   # Shows Windows path unexpectedly

# Working solution:
wsl.exe -d alpine-test --cd /  # Forces Linux root context
```

### 5. Shell Compatibility Failures

**Bash vs Ash:**
```bash
# .bashrc not sourced         # Alpine uses .profile
# [[ ]] syntax errors         # Use [ ] for POSIX
# ${var,,} lowercase          # Not supported in ash
# arrays=(one two three)      # Limited array support
```

### 6. Build Process Failures

**alpine-chroot-install Approach:**
- Dangerous bind mounts (/dev, /proc, /sys)
- Host system corruption risk
- Complex permission management
- **Abandoned** in favor of minirootfs

**Password Policy Modifications:**
```bash
# Tried to modify /etc/login.defs - FAILED
# PAM configuration - FAILED (Alpine minimal PAM)
# Resolution: Use Alpine defaults
```

## Lessons Learned

### Critical Discoveries

1. **Microsoft Documentation is Wrong**
   - Their `--absolute-names` flag breaks WSL imports
   - Always verify documentation with testing

2. **Path Formats are Crucial**
   - Install location MUST be Windows format
   - Tar file path needs `wslpath -w` conversion
   - ERROR_UNHANDLED_EXCEPTION gives no path format hints

3. **Ownership Must be Root (0/0)**
   - Use fakeroot to avoid sudo risks
   - Regular user extraction (1000/1000) always fails
   - `--numeric-owner` is essential

4. **Alpine is Minimal by Design**
   - No systemd (uses OpenRC)
   - No bash by default (uses ash)
   - Many packages missing from repos
   - Respect the minimalist philosophy

5. **Build vs Boot Time**
   - Network operations fail during build
   - Complex installations belong in OOBE
   - Keep build phase minimal

### Best Practices

1. **Test with Vanilla First**
   - Download official minirootfs
   - Test import before customizing
   - Isolates build issues from import issues

2. **Start Simple**
   - Get basic import working
   - Add features incrementally
   - Test after each addition

3. **Document Everything**
   - Failed attempts are valuable
   - Include error messages
   - Note what worked and why

4. **Use Proper Tools**
   - fakeroot for ownership
   - wslpath for path conversion
   - POSIX shell for compatibility

## Troubleshooting Guide

### Quick Diagnostic Checklist

If WSL import fails with ERROR_UNHANDLED_EXCEPTION:

```bash
# 1. Check tar ownership (MUST be 0/0)
tar -tvf alpine-wsl.tar.gz | head -5

# 2. Check tar structure (MUST have ./ prefix)
tar -tf alpine-wsl.tar.gz | head -5
# Good: ./bin/ ./etc/ ./usr/
# Bad: bin/ etc/ usr/

# 3. Verify you used Windows path for install
# Good: wsl.exe --import test "C:\\WSL\\test" file.tar.gz
# Bad: wsl.exe --import test /tmp/test file.tar.gz

# 4. Ensure fakeroot was used
# The tar creation must be: fakeroot tar --numeric-owner -c .
```

### Common Fixes

**Import Fails:**
1. Repackage with: `fakeroot tar --numeric-owner -c . | gzip > alpine.tar.gz`
2. Use Windows path: `"C:\\WSL\\distro-name"`
3. Convert tar path: `$(wslpath -w alpine.tar.gz)`

**OOBE Doesn't Run:**
```bash
wsl.exe -d alpine-wsl -u root /etc/oobe.sh
```

**Docker Won't Start:**
```bash
# Initialize OpenRC
mkdir -p /run/openrc && touch /run/openrc/softlevel
rc-service docker start

# Or manually
sudo dockerd > /dev/null 2>&1 &
```

**Network Issues:**
```bash
# Check connectivity
ping -c 4 dl-cdn.alpinelinux.org

# Update repositories
apk update
```

## Automated Script

Use `wsl-alpine-build-minirootfs.sh` which implements all these fixes:

```bash
# Basic usage
./wsl-alpine-build-minirootfs.sh

# Skip WSL import
./wsl-alpine-build-minirootfs.sh --no-import

# Custom settings
ALPINE_VERSION=3.19.0 DISTRO_NAME=my-alpine ./wsl-alpine-build-minirootfs.sh
```

## Summary

The minirootfs approach is safe, reliable, and follows WSL best practices. The key is understanding the four critical requirements and respecting Alpine's minimal design philosophy. Every failure documented here represents hours of debugging that you can now avoid.