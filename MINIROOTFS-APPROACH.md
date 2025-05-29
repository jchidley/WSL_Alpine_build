# Alpine Linux MinirootFS Approach for WSL

## Executive Summary

The current WSL Alpine build process uses `alpine-chroot-install`, a tool designed for temporary CI/testing environments that creates dangerous bind mounts to the host system. This document proposes a safer, more appropriate approach using Alpine's official mini root filesystem (minirootfs) tarballs.

## Problem with Current Approach

### alpine-chroot-install Issues

1. **Designed for Wrong Use Case**
   - Created for temporary chroot environments in CI systems
   - Not intended for building distributable images
   - Assumes ephemeral environments where cleanup failures don't matter

2. **Dangerous Bind Mounts**
   - Mounts host's `/dev`, `/proc`, `/sys` into chroot
   - Failed cleanup can corrupt host system
   - Already caused deletion of `/dev/null`, `/dev/random`, `/dev/urandom`

3. **Unnecessary Complexity**
   - Requires careful mount/unmount orchestration
   - Needs exit traps and extensive error handling
   - Still vulnerable to edge cases and signal handling issues

## Proper Approach: Alpine MinirootFS

### What is MinirootFS?

Alpine Linux provides official mini root filesystem tarballs specifically designed for:
- Container base images
- Minimal chroot environments
- Custom Linux distributions

These are clean, self-contained root filesystems without any host dependencies.

### Key Advantages

1. **No Host System Risk**
   - No bind mounts required
   - Completely isolated from host
   - Failures only affect temporary directory

2. **Official Alpine Method**
   - Recommended approach for containers and custom distributions
   - Used by Docker, LXC, and other container systems
   - Well-tested and maintained

3. **Simpler Process**
   - Direct file manipulation
   - No chroot complexity
   - Easier to understand and debug

## Implementation Details

### Step 1: Download MinirootFS

```bash
# Define version and architecture
ALPINE_VERSION="3.18.0"
ARCH="x86_64"

# Download from official Alpine CDN
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"

# Verify checksum (should download and verify SHA256)
wget "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256"
sha256sum -c alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz.sha256
```

### Step 2: Extract and Prepare Root Filesystem

```bash
# Create working directory
WORK_DIR="alpine-wsl-build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Extract minirootfs
tar -xzf ../alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz

# Now we have a complete Alpine root filesystem
ls -la
# Shows: bin dev etc home lib media mnt opt proc root run sbin srv sys tmp usr var
```

### Step 3: Customize Without Chroot

Instead of entering chroot (which requires bind mounts), we manipulate files directly:

```bash
# Configure repositories
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

[network]
generateResolvConf = true

[boot]
systemd = false
command = /sbin/openrc boot
EOF

# Add first-boot script
cat > etc/profile.d/first-boot.sh << 'EOF'
#!/bin/sh
if [ ! -f /etc/first-boot-done ]; then
    echo "Running first-boot setup..."
    apk update
    apk add --no-cache sudo bash curl git openssh-client
    touch /etc/first-boot-done
fi
EOF
chmod +x etc/profile.d/first-boot.sh
```

### Step 4: Install Packages Using APK with Root Flag

APK supports installing packages into an alternate root without chroot:

```bash
# Update package database for the target root
apk --root "$PWD" update

# Install packages
apk --root "$PWD" add --no-cache \
    alpine-base \
    openrc \
    util-linux \
    sudo \
    bash \
    curl \
    git \
    helix \
    docker \
    fd \
    bat \
    zoxide \
    fzf

# Configure services
ln -s /etc/init.d/docker etc/runlevels/boot/docker
```

### Step 5: Package for WSL

```bash
# WSL requires specific permissions and ownership
# Package with numeric owners to avoid UID/GID issues
tar --numeric-owner -czf ../alpine-wsl.tar.gz *

# The resulting tarball is ready for WSL import
```

### Step 6: Import into WSL

```bash
# Import the distribution
wsl.exe --import AlpineMinirootFS "$HOME/AlpineMinirootFS" alpine-wsl.tar.gz

# Set default user (optional)
wsl.exe -d AlpineMinirootFS -u root adduser -D -s /bin/bash wsluser
wsl.exe -d AlpineMinirootFS -u root addgroup wsluser wheel

# Configure as default user
cat << EOF | wsl.exe -d AlpineMinirootFS -u root tee -a /etc/wsl.conf
[user]
default = wsluser
EOF

# Restart to apply changes
wsl.exe --terminate AlpineMinirootFS
```

## Comparison with Current Approach

| Aspect | alpine-chroot-install | MinirootFS |
|--------|----------------------|------------|
| **Host Risk** | High (bind mounts) | None |
| **Complexity** | Complex (mounts, cleanup) | Simple (extract, modify) |
| **Use Case** | CI/Testing | Containers/Distributions |
| **Failure Mode** | Can corrupt host | Only affects build dir |
| **Alpine Support** | Third-party tool | Official method |
| **Package Installation** | Inside chroot | APK --root flag |

## Migration Path

1. **Create Parallel Implementation**
   - Develop minirootfs-based script alongside current one
   - Test thoroughly before switching

2. **Feature Parity**
   - Ensure all customizations work with new method
   - Verify package installation process
   - Test first-boot experience

3. **Gradual Transition**
   - Document both approaches
   - Allow users to choose method
   - Deprecate chroot approach after validation

## Technical Considerations

### Package Management Without Chroot

APK's `--root` flag allows full package management without entering chroot:
- Resolves dependencies correctly
- Runs install scripts in confined manner
- Updates package database for target root

### File Permissions and Ownership

- Use `--numeric-owner` when creating tarball
- WSL handles UID/GID mapping automatically
- Avoid permission issues between host and WSL

### Service Management

- OpenRC works without modification
- SystemD requires WSL systemd support flag
- First-boot scripts handle initialization

## Conclusion

The minirootfs approach is:
- **Safer**: No risk to host system
- **Simpler**: No complex mount management
- **Standard**: Official Alpine method
- **Reliable**: Used by production container systems

This approach eliminates the catastrophic failure modes of the current implementation while maintaining all functionality needed for a WSL distribution.