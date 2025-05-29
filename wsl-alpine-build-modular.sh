#!/bin/bash
# ABOUTME: Safe Alpine Linux WSL distribution builder using official minirootfs
# ABOUTME: Modular version using shared libraries for better maintainability

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    
    # Create WSL configuration
    verbose "Creating /etc/wsl.conf"
    dry_run_exec fakeroot tee "$rootfs/etc/wsl.conf" > /dev/null << 'EOF'
[boot]
systemd = false

[network]
hostname = alpine
generateHosts = true
generateResolvConf = true

[user]
default = alpine

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[interop]
enabled = true
appendWindowsPath = true
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
    shadow \
    bash \
    coreutils \
    util-linux \
    procps \
    curl \
    wget \
    git \
    nano \
    vim

# Create default user if it doesn't exist
if ! id alpine >/dev/null 2>&1; then
    echo "Creating default user 'alpine'..."
    adduser -D -s /bin/bash -G wheel alpine
    echo "alpine:alpine" | chpasswd
    
    # Configure sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi

# Set up user home directory
if [ ! -d /home/alpine ]; then
    mkdir -p /home/alpine
    chown -R alpine:alpine /home/alpine
fi

# Create .bashrc if it doesn't exist
if [ ! -f /home/alpine/.bashrc ]; then
    cat > /home/alpine/.bashrc << 'BASHRC'
# Alpine Linux .bashrc for WSL

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Basic prompt
PS1='\u@\h:\w\$ '

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'

# Environment
export PATH=$PATH:/usr/local/bin
BASHRC
    chown alpine:alpine /home/alpine/.bashrc
fi

echo "Setup complete! You can now use Alpine Linux in WSL."
echo "Default user: alpine (password: alpine)"
echo "Please change the password with: passwd"
EOF

    dry_run_exec fakeroot chmod +x "$rootfs/root/setup-alpine-wsl.sh"
    
    # Configure package repositories
    verbose "Configuring Alpine repositories"
    dry_run_exec fakeroot tee "$rootfs/etc/apk/repositories" > /dev/null << EOF
${MIRROR}/v${ALPINE_VERSION%.*}/main
${MIRROR}/v${ALPINE_VERSION%.*}/community
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
    local location="$3"
    
    progress "Installing distribution in WSL..."
    verbose "Distribution name: $name"
    verbose "Install location: $location"
    
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
    
    # Create install location
    dry_run_exec mkdir -p "$location"
    
    # Import the distribution
    progress "Importing distribution..."
    if ! dry_run_exec wsl.exe --import "$name" "$location" "$tarball"; then
        error "Failed to import distribution"
        return 1
    fi
    
    success "Distribution installed successfully!"
    
    # Show post-install instructions
    echo
    echo "To complete the setup:"
    echo "1. Start the distribution: wsl -d $name"
    echo "2. Run the setup script: /root/setup-alpine-wsl.sh"
    echo "3. Exit and restart as the default user: wsl -d $name -u alpine"
    echo
    
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