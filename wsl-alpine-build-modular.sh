#!/bin/bash
# ABOUTME: Safe Alpine Linux WSL distribution builder using official minirootfs
# ABOUTME: Modular version using shared libraries for better maintainability

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize variables before error handling setup
export DEBUG="${DEBUG:-0}"
export VERBOSE="${VERBOSE:-0}"
export DRY_RUN="${DRY_RUN:-0}"

# Source shared libraries
source "${SCRIPT_DIR}/src/lib/common.sh"
source "${SCRIPT_DIR}/src/lib/prerequisites.sh"

# Set up error handling
setup_error_handling

# Default configuration
ALPINE_VERSION="${ALPINE_VERSION:-3.18.6}"
ARCH="${ARCH:-x86_64}"
BUILD_DIR="${BUILD_DIR:-alpine-wsl-build}"
ROOTFS_DIR="${ROOTFS_DIR:-$BUILD_DIR/rootfs}"
DISTRO_NAME="${DISTRO_NAME:-alpine-wsl}"
INSTALL_LOCATION="${INSTALL_LOCATION:-/tmp/wsl-alpine-install}"
OUTPUT_FILE="${OUTPUT_FILE:-alpine-wsl.tar.gz}"

# URLs
MIRROR="${MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
MINIROOTFS_URL="${MIRROR}/v${ALPINE_VERSION%.*}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"

# Override cleanup function
cleanup() {
    debug "Running build cleanup..."
    if [[ -d "$BUILD_DIR" ]] && [[ "$BUILD_DIR" != "/" ]]; then
        verbose "Cleaning up build directory: $BUILD_DIR"
        dry_run_exec rm -rf "$BUILD_DIR"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [options]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -d, --debug         Enable debug mode
    -n, --dry-run       Show what would be done without making changes
    --version VERSION   Alpine version (default: $ALPINE_VERSION)
    --arch ARCH         Architecture (default: $ARCH)
    --name NAME         Distribution name (default: $DISTRO_NAME)
    --output FILE       Output file name (default: $OUTPUT_FILE)

Environment variables:
    ALPINE_VERSION      Alpine version to use
    ARCH                Architecture (x86_64, aarch64, etc.)
    DISTRO_NAME         WSL distribution name
    BUILD_DIR           Build directory
    OUTPUT_FILE         Output tarball name
    DEBUG               Enable debug mode (0/1)
    VERBOSE             Enable verbose mode (0/1)
    DRY_RUN             Enable dry-run mode (0/1)

Example:
    $0 --verbose --name alpine-dev --version 3.19.0
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                export VERBOSE=1
                ;;
            -d|--debug)
                export DEBUG=1
                ;;
            -n|--dry-run)
                export DRY_RUN=1
                ;;
            --version)
                ALPINE_VERSION="$2"
                shift
                ;;
            --arch)
                ARCH="$2"
                shift
                ;;
            --name)
                DISTRO_NAME="$2"
                shift
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

# Download Alpine minirootfs
download_minirootfs() {
    local url="$1"
    local dest="$2"
    
    progress "Downloading Alpine minirootfs ${ALPINE_VERSION}..."
    verbose "URL: $url"
    verbose "Destination: $dest"
    
    if ! dry_run_exec wget -q --show-progress -O "$dest" "$url"; then
        error "Failed to download minirootfs"
        return 1
    fi
    
    # Verify checksum if available
    local checksum_url="${url}.sha256"
    local checksum_file="${dest}.sha256"
    
    verbose "Downloading checksum from: $checksum_url"
    if wget -q -O "$checksum_file" "$checksum_url" 2>/dev/null; then
        progress "Verifying checksum..."
        local expected_sum=$(awk '{print $1}' "$checksum_file")
        local actual_sum=$(sha256sum "$dest" | awk '{print $1}')
        
        if [[ "$expected_sum" != "$actual_sum" ]]; then
            error "Checksum verification failed!"
            error "Expected: $expected_sum"
            error "Actual: $actual_sum"
            return 1
        fi
        success "Checksum verified"
    else
        warning "Could not download checksum file, skipping verification"
    fi
    
    return 0
}

# Extract minirootfs
extract_rootfs() {
    local tarball="$1"
    local dest="$2"
    
    progress "Extracting rootfs..."
    verbose "Source: $tarball"
    verbose "Destination: $dest"
    
    # Create destination directory
    dry_run_exec mkdir -p "$dest"
    
    # Extract with fakeroot to preserve permissions
    if ! dry_run_exec fakeroot tar -xzf "$tarball" -C "$dest"; then
        error "Failed to extract rootfs"
        return 1
    fi
    
    success "Rootfs extracted"
    return 0
}

# Configure Alpine for WSL
configure_wsl() {
    local rootfs="$1"
    
    progress "Configuring Alpine for WSL..."
    
    # Get current username
    local username="${SUDO_USER:-$USER}"
    
    # Create WSL configuration
    verbose "Creating /etc/wsl.conf"
    dry_run_exec fakeroot tee "$rootfs/etc/wsl.conf" > /dev/null << EOF
[boot]
systemd = false
command = /sbin/openrc boot

[network]
hostname = alpine
generateHosts = true
generateResolvConf = true

[user]
default = $username

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[interop]
enabled = true
appendWindowsPath = true
EOF

    # Configure network for Docker
    verbose "Setting up network configuration for Docker"
    dry_run_exec fakeroot mkdir -p "$rootfs/etc/network"
    dry_run_exec fakeroot tee "$rootfs/etc/network/interfaces" > /dev/null << EOF
# /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback
EOF

    # Create WSL-specific directories and terminal profile
    verbose "Creating WSL terminal profile"
    dry_run_exec fakeroot mkdir -p "$rootfs/usr/lib/wsl"
    dry_run_exec fakeroot tee "$rootfs/usr/lib/wsl/terminal-profile.json" > /dev/null << EOF
{
  "profiles": [
    {
      "colorScheme": "Gruvbox Dark (Hard)"
    }
  ]
}
EOF

    # Create setup script for first boot
    verbose "Creating first-boot setup script"
    dry_run_exec fakeroot tee "$rootfs/root/setup-alpine-wsl.sh" > /dev/null << 'EOF'
#!/bin/sh
set -e

echo "Setting up Alpine Linux for WSL..."

# Update package repositories
echo "Updating package repositories..."
apk update

# Install basic packages
echo "Installing basic packages..."
apk add --no-cache \
    sudo \
    git \
    openrc \
    helix \
    fd \
    bat \
    zoxide \
    fzf

# Add testing repository for additional packages
echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Install additional packages including Docker
echo "Installing additional packages..."
apk update
apk add --no-cache \
    docker \
    lazydocker

# Enable Docker service
echo "Enabling Docker service..."
ln -sf /etc/init.d/docker /etc/runlevels/boot/docker

# Create wheel group if it doesn't exist
if ! grep -q "^wheel:" /etc/group; then
    echo "Creating wheel group..."
    addgroup -S wheel
fi

# Get the username from wsl.conf or use alpine as fallback
USERNAME=$(grep "^default" /etc/wsl.conf 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "alpine")

# Create default user if it doesn't exist
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "Creating default user '$USERNAME'..."
    adduser -D -s /bin/ash "$USERNAME"
    adduser "$USERNAME" wheel
    # Set a temporary password (same as username)
    echo "$USERNAME:$USERNAME" | chpasswd
    
    # Configure sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi

# Set up user home directory
if [ ! -d "/home/$USERNAME" ]; then
    mkdir -p "/home/$USERNAME"
fi
# Fix ownership after user is created
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

# Configure Helix editor
echo "Configuring Helix editor..."
mkdir -p "/home/$USERNAME/.config/helix"
cat > "/home/$USERNAME/.config/helix/config.toml" << 'HELIX_EOF'
theme = "gruvbox_dark_hard"
HELIX_EOF
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"

# Create .profile if it doesn't exist
if [ ! -f "/home/$USERNAME/.profile" ]; then
    cat > "/home/$USERNAME/.profile" << 'PROFILE'
# Alpine Linux .profile for WSL

# Check if password needs to be changed on first login
if [ -f "$HOME/.first-login" ]; then
    echo "Welcome to Alpine Linux on WSL!"
    echo ""
    echo "For security, you must change your password now."
    passwd
    if [ $? -eq 0 ]; then
        rm -f "$HOME/.first-login"
        echo ""
        echo "Password changed successfully!"
        echo ""
    else
        echo "Password change failed. Please try again."
        exit 1
    fi
fi

# Basic prompt
PS1='\u@\h:\w\$ '

# Aliases
alias ll='ls -la'

# Environment
export PATH=$PATH:/usr/local/bin
export COLORTERM=truecolor

# Initialize zoxide
eval "$(zoxide init posix --hook prompt)"

# If bash is installed and user wants it, they can uncomment this
# [ -x /bin/bash ] && exec /bin/bash
PROFILE
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.profile"
    
    # Create first-login marker
    touch "/home/$USERNAME/.first-login"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.first-login"
fi

echo "Setup complete! You can now use Alpine Linux in WSL."
echo "Default user: $USERNAME (temporary password: $USERNAME)"
echo ""
echo "You will be prompted to change your password on first login."

# Configure Helix editor for root
mkdir -p /root/.config/helix
cat > /root/.config/helix/config.toml << 'HELIX_CONFIG'
theme = "gruvbox_dark_hard"
HELIX_CONFIG

# Configure root shell
cat > /root/.profile << 'ROOT_PROFILE'
export COLORTERM=truecolor
eval "$(zoxide init posix --hook prompt)"
ROOT_PROFILE

# Mark that setup is complete
touch /root/.setup-complete
EOF

    dry_run_exec fakeroot chmod +x "$rootfs/root/setup-alpine-wsl.sh"
    
    # Configure package repositories
    verbose "Configuring Alpine repositories"
    dry_run_exec fakeroot tee "$rootfs/etc/apk/repositories" > /dev/null << EOF
${MIRROR}/v${ALPINE_VERSION%.*}/main
${MIRROR}/v${ALPINE_VERSION%.*}/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

    success "WSL configuration complete"
    return 0
}

# Package the distribution
package_distribution() {
    local rootfs="$1"
    local output="$2"
    
    progress "Packaging distribution..."
    verbose "Source: $rootfs"
    verbose "Output: $output"
    
    # Create tarball with fakeroot to preserve permissions
    if ! dry_run_exec fakeroot tar -czf "$output" -C "$rootfs" .; then
        error "Failed to create distribution package"
        return 1
    fi
    
    local size=$(du -h "$output" 2>/dev/null | cut -f1)
    success "Distribution packaged: $output ($size)"
    return 0
}

# Install distribution in WSL
install_wsl() {
    local tarball="$1"
    local name="$2"
    local location="$3"  # Not used anymore, keeping for compatibility
    
    progress "Installing distribution in WSL..."
    verbose "Distribution name: $name"
    
    # Check if distribution already exists
    if wsl.exe --list --quiet | grep -q "^${name}$"; then
        warning "Distribution '$name' already exists"
        read -p "Do you want to unregister it and continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled"
            return 1
        fi
        
        progress "Unregistering existing distribution..."
        dry_run_exec wsl.exe --unregister "$name"
    fi
    
    # Convert paths to Windows format
    local win_install_location="C:\\WSL\\$name"
    local win_tar_path=$(wslpath -w "$tarball")
    
    # Import the distribution
    progress "Importing distribution..."
    verbose "Windows install location: $win_install_location"
    verbose "Windows tar path: $win_tar_path"
    
    if ! dry_run_exec wsl.exe --import "$name" "$win_install_location" "$win_tar_path" --version 2; then
        error "Failed to import distribution"
        return 1
    fi
    
    success "Distribution installed successfully!"
    
    # Get current username
    local username="${SUDO_USER:-$USER}"
    
    # Run the setup script automatically
    echo
    progress "Running initial setup..."
    if ! dry_run_exec wsl.exe -d "$name" --cd / -e /root/setup-alpine-wsl.sh; then
        error "Setup script failed"
        return 1
    fi
    
    # Launch as the user
    echo
    success "Alpine Linux is ready!"
    echo
    echo "To start using Alpine Linux:"
    echo "  wsl.exe -d $name -u $username --cd /home/$username"
    echo
    echo "You will be prompted to change your password on first login."
    
    return 0
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Show configuration
    if [[ "$VERBOSE" == "1" ]]; then
        echo "Configuration:"
        echo "  Alpine Version: $ALPINE_VERSION"
        echo "  Architecture: $ARCH"
        echo "  Distribution Name: $DISTRO_NAME"
        echo "  Build Directory: $BUILD_DIR"
        echo "  Output File: $OUTPUT_FILE"
        echo
    fi
    
    # Check prerequisites
    check_prerequisites || exit 1
    
    # Get system info in verbose mode
    [[ "$VERBOSE" == "1" ]] && get_system_info
    
    # Create build directory
    progress "Creating build directory..."
    dry_run_exec mkdir -p "$BUILD_DIR"
    
    # Download minirootfs
    local minirootfs_file="$BUILD_DIR/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
    download_minirootfs "$MINIROOTFS_URL" "$minirootfs_file" || exit 1
    
    # Extract rootfs
    extract_rootfs "$minirootfs_file" "$ROOTFS_DIR" || exit 1
    
    # Configure for WSL
    configure_wsl "$ROOTFS_DIR" || exit 1
    
    # Package distribution
    package_distribution "$ROOTFS_DIR" "$OUTPUT_FILE" || exit 1
    
    # Optional: Install in WSL
    if [[ "$DRY_RUN" != "1" ]]; then
        read -p "Do you want to install the distribution in WSL now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_wsl "$OUTPUT_FILE" "$DISTRO_NAME" "$INSTALL_LOCATION" || exit 1
        fi
    fi
    
    success "Build complete!"
    
    # Clean up
    cleanup
}

# Run main function
main "$@"