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

    # Configure Docker service to start at boot
    verbose "Configuring Docker service"
    # Create runlevel directories if they don't exist
    dry_run_exec fakeroot mkdir -p "$rootfs/etc/runlevels/boot"
    dry_run_exec fakeroot mkdir -p "$rootfs/etc/runlevels/default"
    
    # Create symlink for Docker service in boot runlevel
    # This will be activated once Docker is installed
    dry_run_exec fakeroot ln -sf /etc/init.d/docker "$rootfs/etc/runlevels/boot/docker" || true
    
    # Create docker group
    verbose "Creating docker group"
    if [[ "$DRY_RUN" != "1" ]]; then
        echo "docker:x:102:" >> "$rootfs/etc/group" || true
    fi

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

# Docker service is already configured to start at boot
echo "Docker service configured to start at boot"


# Fix critical setuid binaries that fakeroot doesn't preserve
echo "Fixing setuid permissions..."
# passwd must be setuid for users to change their own passwords
if [ -f /usr/bin/passwd ]; then
    chmod u+s /usr/bin/passwd
fi
# su might be in different locations or not installed
for su_path in /usr/bin/su /bin/su; do
    [ -f "$su_path" ] && chmod u+s "$su_path"
done

# Install shadow package for proper user management
echo "Installing shadow package..."
apk add --no-cache shadow shadow-login

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
    
    # Add user to docker group for Docker access
    adduser "$USERNAME" docker 2>/dev/null || echo "Docker group will be configured later"
    
    # Set password from environment or use a default
    if [ -n "$ALPINE_USER_PASSWORD" ]; then
        echo "$USERNAME:$ALPINE_USER_PASSWORD" | chpasswd
    else
        # Fallback to temporary password if not provided
        TEMP_PASS="${USERNAME}Alpine2024!"
        echo "$USERNAME:$TEMP_PASS" | chpasswd
    fi
    
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

# First login message
if [ -f "$HOME/.first-login" ]; then
    echo "Welcome to Alpine Linux on WSL!"
    echo ""
    echo "Optional: To install Claude Code, run:"
    echo "  sudo install-claude-code        # For native installation"
    echo "  sudo install-claude-code docker  # For Docker installation"
    echo ""
    rm -f "$HOME/.first-login"
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
echo "Default user: $USERNAME"
if [ -z "$ALPINE_USER_PASSWORD" ]; then
    echo "Temporary password: ${USERNAME}Alpine2024!"
    echo "To change your password after login, use: passwd"
fi

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

# Create Claude Code installation script
cat > /usr/local/bin/install-claude-code << 'CLAUDE_SCRIPT'
#!/bin/ash
# Install Claude Code in Alpine Linux

set -e

echo "Claude Code Installer for Alpine Linux"
echo "======================================"
echo ""

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "Please run with sudo: sudo install-claude-code"
    exit 1
fi

# Default to native installation
INSTALL_METHOD="${1:-native}"

case "$INSTALL_METHOD" in
    native|--native)
        echo "Installing Claude Code (native)..."
        
        # Install Node.js and npm
        echo "Installing Node.js and npm..."
        apk add --no-cache nodejs npm
        
        # Install Claude Code
        echo "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
        
        # Create config directory
        mkdir -p /root/.config/claude-code
        cat > /root/.config/claude-code/config.json << 'CONFIG'
{
    "telemetry": {
        "enabled": false
    },
    "editor": {
        "default": "hx"
    }
}
CONFIG
        
        # Also create for regular user if exists
        if [ -n "$SUDO_USER" ]; then
            USER_HOME="/home/$SUDO_USER"
            mkdir -p "$USER_HOME/.config/claude-code"
            cp /root/.config/claude-code/config.json "$USER_HOME/.config/claude-code/"
            chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config"
        fi
        
        echo ""
        echo "✅ Claude Code installed successfully!"
        echo ""
        echo "To use Claude Code:"
        echo "  1. Run: claude login"
        echo "  2. Follow the browser authentication flow"
        echo "  3. Start coding with: claude"
        echo ""
        echo "For containers/CI, use: claude --dangerously-skip-permissions"
        ;;
        
    docker|--docker)
        echo "Installing Claude Code (Docker)..."
        
        # Check if Docker daemon is accessible
        echo "Checking Docker status..."
        
        # First ensure Docker service is started
        if ! rc-service docker status >/dev/null 2>&1; then
            echo "Docker service is not running. Starting..."
            rc-service docker start || {
                echo "❌ Failed to start Docker service"
                echo ""
                echo "This might be due to WSL/OpenRC initialization issues."
                echo "Please try:"
                echo "  1. Exit and re-enter WSL: wsl.exe --terminate $WSL_DISTRO_NAME && wsl.exe -d $WSL_DISTRO_NAME"
                echo "  2. Manually start Docker: sudo rc-service docker start"
                echo "  3. Check Docker logs: sudo dockerd --debug"
                exit 1
            }
        fi
        
        # Wait for Docker daemon to be ready
        echo "Waiting for Docker daemon to be ready..."
        DOCKER_READY=0
        for i in $(seq 1 60); do
            if docker info >/dev/null 2>&1; then
                DOCKER_READY=1
                echo "✅ Docker is ready"
                break
            fi
            # Every 10 seconds, show a message
            if [ $((i % 10)) -eq 0 ]; then
                echo "Still waiting for Docker daemon... ($i/60)"
            fi
            sleep 1
        done
        
        if [ $DOCKER_READY -eq 0 ]; then
            echo "❌ Docker daemon failed to start within 60 seconds"
            echo ""
            echo "Troubleshooting:"
            echo "  1. Check if dockerd process is running: ps aux | grep dockerd"
            echo "  2. Check Docker logs: sudo tail -50 /var/log/docker.log"
            echo "  3. Try starting manually: sudo dockerd --debug"
            echo "  4. Check kernel support: lsmod | grep overlay"
            exit 1
        fi
        
        # Create Dockerfile
        cat > /tmp/claude-dockerfile << 'DOCKERFILE'
FROM node:20-alpine
RUN apk add --no-cache git bash curl make g++ python3
RUN npm install -g @anthropic-ai/claude-code
RUN adduser -D -s /bin/bash claude
RUN mkdir -p /workspace && chown claude:claude /workspace
USER claude
WORKDIR /workspace
ENTRYPOINT ["claude"]
DOCKERFILE
        
        # Build image
        echo "Building Docker image..."
        docker build -t claude-code:alpine -f /tmp/claude-dockerfile /tmp/
        
        # Create wrapper
        cat > /usr/local/bin/claude-docker << 'WRAPPER'
#!/bin/sh
docker run -it --rm \
    -v "${PWD}:/workspace" \
    -v "$HOME/.config:/home/claude/.config" \
    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" \
    --network="${CLAUDE_NETWORK:-bridge}" \
    claude-code:alpine "$@"
WRAPPER
        chmod +x /usr/local/bin/claude-docker
        
        # Clean up
        rm -f /tmp/claude-dockerfile
        
        echo ""
        echo "✅ Claude Code Docker setup complete!"
        echo ""
        echo "To use Claude Code:"
        echo "  1. Run: claude-docker login"
        echo "  2. Follow the browser authentication flow"
        echo "  3. Start coding with: claude-docker"
        echo ""
        echo "For containers/CI, use: claude-docker --dangerously-skip-permissions"
        ;;
        
    *)
        echo "Usage: $0 [native|docker]"
        echo ""
        echo "Options:"
        echo "  native  - Install Claude Code directly (default)"
        echo "  docker  - Install Claude Code in Docker container"
        exit 1
        ;;
esac

echo ""
echo "Installation complete!"
CLAUDE_SCRIPT

chmod +x /usr/local/bin/install-claude-code

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
    
    # Prompt for user password
    echo
    echo "Please set a password for user '$username' in the new Alpine distribution."
    echo "Password requirements: minimum 8 characters"
    while true; do
        read -s -p "Enter password: " user_password
        echo
        read -s -p "Confirm password: " user_password_confirm
        echo
        
        if [ "$user_password" != "$user_password_confirm" ]; then
            echo "Passwords do not match. Please try again."
            continue
        fi
        
        if [ ${#user_password} -lt 8 ]; then
            echo "Password must be at least 8 characters. Please try again."
            continue
        fi
        
        break
    done
    
    # Pass password via environment variable
    export ALPINE_USER_PASSWORD="$user_password"
    
    # Run the setup script automatically
    echo
    progress "Running initial setup..."
    if ! dry_run_exec wsl.exe -d "$name" --cd / -e env ALPINE_USER_PASSWORD="$ALPINE_USER_PASSWORD" /root/setup-alpine-wsl.sh; then
        error "Setup script failed"
        unset ALPINE_USER_PASSWORD
        return 1
    fi
    
    # Clear password from environment
    unset ALPINE_USER_PASSWORD
    
    # Launch as the user
    echo
    success "Alpine Linux is ready!"
    echo
    echo "To start using Alpine Linux:"
    echo "  wsl.exe -d $name -u $username --cd /home/$username"
    echo
    echo "Note: Docker is configured to start automatically."
    echo "On first use, you may need to wait a moment for the Docker daemon to initialize."
    
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