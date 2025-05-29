# Building Alpine Linux for WSL using MinirootFS

## Quick Summary

This guide shows how to build a custom Alpine Linux distribution for WSL 2 using the official minirootfs approach. Key requirements:

1. **Use `fakeroot`** to preserve root ownership without sudo
2. **Use Windows paths** (C:\WSL\...) for WSL import location  
3. **Package with `tar -c .`** not `tar -c *` for correct structure
4. **Never use dangerous bind mounts** or chroot operations

## Overview

This document describes how to build a custom Alpine Linux distribution for Windows Subsystem for Linux (WSL) using Alpine's official mini root filesystem (minirootfs) tarballs. This approach creates a clean, safe, and WSL-compliant distribution without requiring dangerous bind mounts or chroot operations.

## What is MinirootFS?

Alpine Linux provides official mini root filesystem tarballs specifically designed for:
- Container base images
- Custom Linux distributions
- Minimal system deployments

These are clean, self-contained root filesystems that serve as the foundation for building custom distributions.

## Prerequisites

- Linux environment (WSL, VM, or native)
- Basic tools: `wget`, `tar`, `gzip`, `sha256sum`
- `fakeroot` - Required to preserve root ownership without sudo
- Access to `wsl.exe` command for importing the distribution

## Build Process

### Step 1: Download Alpine MinirootFS

```bash
# Set version and architecture
ALPINE_VERSION="3.18.6"  # Use latest stable
ARCH="x86_64"

# Create build directory
BUILD_DIR="alpine-wsl-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download minirootfs
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"

# Download and verify checksum
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
sha256sum -c "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
```

### Step 2: Extract Root Filesystem

```bash
# Create working directory for extraction
ROOTFS_DIR="rootfs"
mkdir -p "$ROOTFS_DIR"

# Extract minirootfs (preserves root ownership from the archive)
tar -xzf "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz" -C "$ROOTFS_DIR"

# Verify extraction
ls -la "$ROOTFS_DIR"
# Should show: bin dev etc home lib media mnt opt proc root run sbin srv sys tmp usr var
```

### Step 3: Configure for WSL

Create all necessary configuration files for WSL compliance:

```bash
cd "$ROOTFS_DIR"

# Configure APK repositories
cat > etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/v3.18/main
https://dl-cdn.alpinelinux.org/alpine/v3.18/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

# Create WSL configuration
cat > etc/wsl.conf << 'EOF'
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true
root = /mnt/

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[boot]
systemd = false
command = /sbin/openrc default
EOF

# Create WSL distribution configuration
cat > etc/wsl-distribution.conf << 'EOF'
[oobe]
default = alpine-wsl
command = /etc/oobe.sh
EOF

# Create Out-of-Box Experience (OOBE) script
cat > etc/oobe.sh << 'EOF'
#!/bin/sh
# Alpine WSL Out-of-Box Experience

# Exit if already run
if [ -f /etc/oobe.done ]; then
    exit 0
fi

echo "╔══════════════════════════════════════════╗"
echo "║   Welcome to Alpine Linux for WSL!       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Running first-time setup..."

# Update package database
echo "→ Updating package database..."
apk update

# Install base packages
echo "→ Installing essential packages..."
apk add --no-cache \
    alpine-base \
    openrc \
    util-linux \
    sudo \
    bash \
    shadow \
    e2fsprogs \
    e2fsprogs-extra

# Install development tools
echo "→ Installing development tools..."
apk add --no-cache \
    git \
    curl \
    wget \
    openssh-client \
    build-base

# Install modern CLI tools
echo "→ Installing modern CLI tools..."
apk add --no-cache \
    helix \
    fd \
    bat \
    zoxide \
    fzf \
    ripgrep \
    tree

# Install Docker
echo "→ Installing Docker..."
apk add --no-cache \
    docker \
    docker-cli-compose \
    lazydocker

# Install tree-sitter grammars for Helix
echo "→ Installing Helix syntax highlighting..."
apk add --no-cache \
    tree-sitter-markdown@testing \
    tree-sitter-css \
    tree-sitter-html \
    tree-sitter-javascript \
    tree-sitter-typescript \
    tree-sitter-python \
    tree-sitter-rust \
    tree-sitter-c \
    tree-sitter-bash

# Configure services
echo "→ Configuring services..."
rc-update add docker boot

# Create default user (UID 1000 as per Microsoft recommendations)
echo "→ Creating default user..."
adduser -D -u 1000 -s /bin/bash -h /home/wsluser -g "WSL User" wsluser
echo "wsluser:wsluser" | chpasswd
addgroup wsluser wheel
addgroup wsluser docker

# Configure sudo
mkdir -p /etc/sudoers.d
echo "wsluser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wsluser
chmod 440 /etc/sudoers.d/wsluser

# Configure user environment
mkdir -p /home/wsluser/.config/helix
cat > /home/wsluser/.config/helix/config.toml << 'HELIX'
theme = "gruvbox_dark_hard"

[editor]
line-number = "relative"
mouse = true
rulers = [80, 120]

[editor.indent-guides]
render = true
HELIX
chown -R wsluser:wsluser /home/wsluser/.config

# Add shell configuration
cat >> /home/wsluser/.bashrc << 'BASHRC'
# Alpine WSL customizations
export COLORTERM=truecolor
export EDITOR=hx

# Initialize zoxide
eval "$(zoxide init bash)"

# Better ls
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'

# Git aliases
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph'

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias lzd='lazydocker'
BASHRC
chown wsluser:wsluser /home/wsluser/.bashrc

# Update wsl.conf with default user
cat >> /etc/wsl.conf << 'WSLCONF'

[user]
default = wsluser
WSLCONF

# Clean up
echo "→ Cleaning up..."
rm -rf /var/cache/apk/*

# Mark as complete
touch /etc/oobe.done

echo ""
echo "✓ First-time setup complete!"
echo ""
echo "The distribution will now restart with the default user."
echo "Please close this window and run:"
echo "  wsl.exe --terminate alpine-wsl"
echo "  wsl.exe -d alpine-wsl"
echo ""
echo "Default credentials:"
echo "  Username: wsluser"
echo "  Password: wsluser"
echo ""
EOF
chmod +x etc/oobe.sh

# Ensure proper /etc/passwd entries
cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/ash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
EOF

# Create essential directories
mkdir -p proc sys dev tmp
chmod 1777 tmp

# Remove resolv.conf to let WSL generate it
rm -f etc/resolv.conf

cd ..
```

### Step 4: Install Base Packages (Optional)

You can pre-install packages to reduce first-boot time:

```bash
# Install APK tools on your build system if not available
# For Debian/Ubuntu:
# sudo apt-get install alpine-conf

# Install base packages into the root filesystem
apk --root "$ROOTFS_DIR" --initdb add alpine-base

# Update package database
apk --root "$ROOTFS_DIR" --arch "$ARCH" --repository https://dl-cdn.alpinelinux.org/alpine/v3.18/main --repository https://dl-cdn.alpinelinux.org/alpine/v3.18/community update

# Pre-install essential packages (optional - can be done in OOBE)
apk --root "$ROOTFS_DIR" --arch "$ARCH" add \
    openrc \
    util-linux \
    bash \
    sudo
```

### Step 5: Package for WSL

```bash
# CRITICAL: Must use fakeroot to preserve root ownership (0/0)
# Create a packaging script to run under fakeroot
cat > package.sh << 'SCRIPT'
#!/bin/bash
set -e
cd "$1"
tar --numeric-owner -c . | gzip --fast > ../alpine-wsl.tar.gz
SCRIPT
chmod +x package.sh

# Run packaging under fakeroot to preserve ownership
fakeroot -- ./package.sh "$ROOTFS_DIR"

# Verify the package has correct ownership
tar -tvf alpine-wsl.tar.gz | head -10
# Should show: 0/0 ownership and paths like ./bin/, ./etc/, ./usr/

# Optional: Create .wsl file for double-click install
cp alpine-wsl.tar.gz alpine-wsl.wsl
```

**Important Notes on Tar Format**:
- `--numeric-owner`: Preserves numeric UIDs/GIDs (required for WSL)
- NO `--absolute-names`: This flag would break WSL import
- `-c .`: Creates archive with proper `./` prefix structure
- `fakeroot`: Essential to maintain root (0/0) ownership without sudo
- `gzip --fast`: Fast compression for quicker build times

### Step 6: Import into WSL

```bash
# Define distribution name
DISTRO_NAME="alpine-wsl"

# CRITICAL: WSL 2 requires Windows paths for install location
# Convert tar file path to Windows format
WIN_TAR_PATH=$(wslpath -w alpine-wsl.tar.gz)

# Import the distribution with Windows path for install location
wsl.exe --import "$DISTRO_NAME" "C:\\WSL\\$DISTRO_NAME" "$WIN_TAR_PATH" --version 2

# Verify installation
wsl.exe --list --verbose

# First launch will trigger OOBE script
wsl.exe -d "$DISTRO_NAME"
```

**Important Notes on WSL Import**:
- Install location MUST be a Windows path (C:\WSL\...) not a Linux path
- Use `wslpath -w` to convert Linux paths to Windows format
- The `--version 2` flag ensures WSL 2 is used
- WSL will create the install directory if it doesn't exist

## Post-Installation

After the OOBE script completes and you restart the distribution:

1. **Change default password**:
   ```bash
   passwd
   ```

2. **Start Docker service**:
   ```bash
   sudo rc-service docker start
   ```

3. **Verify installation**:
   ```bash
   # Check Alpine version
   cat /etc/alpine-release
   
   # Check installed packages
   apk list --installed
   
   # Test Docker
   sudo docker run --rm hello-world
   ```

## Customization

### Adding More Packages

Edit the OOBE script before building to include additional packages:

```bash
# In etc/oobe.sh, add to the appropriate section:
apk add --no-cache \
    nodejs \
    npm \
    python3 \
    py3-pip \
    rust \
    cargo
```

### Changing Default Settings

Modify `etc/wsl.conf` to adjust WSL behavior:

```ini
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true
root = /mnt/

[network]
generateHosts = true
generateResolvConf = true
hostname = alpine-dev

[interop]
enabled = true
appendWindowsPath = false  # Set to false for pure Linux environment
```

### Using SystemD Instead of OpenRC

To use systemd (requires Windows 11 or Windows 10 with WSL2 v0.67.6+):

```ini
# In etc/wsl.conf
[boot]
systemd = true
# Remove the command = /sbin/openrc line
```

## Troubleshooting

### WSL Import Fails with ERROR_UNHANDLED_EXCEPTION

This error typically occurs due to:

1. **Incorrect tar file ownership**: Files must be owned by root (0/0)
   ```bash
   # Check ownership in tar file
   tar -tvf alpine-wsl.tar.gz | head -10
   # Should show: drwxr-xr-x 0/0 (not 1000/1000)
   ```

2. **Wrong install location path format**: Must use Windows paths
   ```bash
   # Wrong: Linux path
   wsl.exe --import test /home/user/wsl/test alpine.tar.gz
   
   # Correct: Windows path
   wsl.exe --import test "C:\\WSL\\test" alpine.tar.gz
   ```

3. **Missing fakeroot during packaging**: Repackage with fakeroot
   ```bash
   fakeroot tar --numeric-owner -c . | gzip > alpine-wsl.tar.gz
   ```

### OOBE Script Doesn't Run

If the first-boot script doesn't execute:

```bash
# Manually run as root
wsl.exe -d alpine-wsl -u root /etc/oobe.sh
```

### Package Installation Fails

If APK commands fail during OOBE:

```bash
# Check network connectivity
wsl.exe -d alpine-wsl -u root ping -c 4 dl-cdn.alpinelinux.org

# Manually update repositories
wsl.exe -d alpine-wsl -u root apk update
```

### Permission Issues

If you encounter permission problems:

```bash
# Fix ownership
wsl.exe -d alpine-wsl -u root chown -R wsluser:wsluser /home/wsluser

# Verify sudo configuration
wsl.exe -d alpine-wsl -u root visudo -c
```

### Tar File Structure Issues

Common tar format problems:

```bash
# Wrong: Files without directory prefix
bin/sh
etc/passwd

# Wrong: Absolute paths
/bin/sh
/etc/passwd

# Correct: Relative paths with ./
./bin/sh
./etc/passwd
```

## Advantages of This Approach

1. **Safety**: No bind mounts or chroot operations that could damage the host system
2. **Simplicity**: Direct file manipulation without complex mount orchestration
3. **Reliability**: Uses Alpine's official distribution method
4. **Compliance**: Follows Microsoft's WSL distribution guidelines
5. **Reproducibility**: Easy to script and automate

## Key Discoveries and Best Practices

### Critical Requirements for WSL 2

1. **File Ownership**: All files in the tar must be owned by root (0/0)
   - Use `fakeroot` to achieve this without sudo
   - Regular user extraction results in wrong ownership (1000/1000)

2. **Path Formats**: 
   - Install location MUST be Windows path (C:\WSL\...)
   - Tar file path can be converted with `wslpath -w`
   - Linux paths for install location cause ERROR_UNHANDLED_EXCEPTION

3. **Tar Archive Structure**:
   - Use `tar -c .` not `tar -c *` for proper structure
   - Files must have `./` prefix (./bin/, ./etc/)
   - Never use `--absolute-names` flag

4. **Build Environment**:
   - No need for sudo or root access
   - `fakeroot` provides necessary ownership simulation
   - Safer than chroot-based approaches

### Common Pitfalls to Avoid

- Don't use alpine-chroot-install for WSL distributions (it's for CI/testing)
- Don't bind mount /dev, /proc, /sys (corruption risk)
- Don't assume Microsoft's documentation is always accurate
- Don't skip checksum verification of downloaded files
- Don't forget to remove /etc/resolv.conf (let WSL generate it)

## Automated Build Script

An automated script `wsl-alpine-build-minirootfs.sh` is now available that implements this entire process with all discoveries and fixes applied:

```bash
# Basic usage
./wsl-alpine-build-minirootfs.sh

# Build without automatic WSL import
./wsl-alpine-build-minirootfs.sh --no-import

# Customize build with environment variables
ALPINE_VERSION=3.19.0 DISTRO_NAME=my-alpine ./wsl-alpine-build-minirootfs.sh
```

The script features:
- Automatic download and verification of Alpine minirootfs
- Safe build process without dangerous bind mounts
- Proper use of fakeroot for correct ownership
- Windows path handling for WSL import
- Progress indicators and error handling
- Optional WSL import with conflict detection
- Configurable through environment variables

## Next Steps

- Add CI/CD pipeline for regular updates
- Customize for specific development environments
- Test with different Alpine versions
- Share with the Alpine/WSL community