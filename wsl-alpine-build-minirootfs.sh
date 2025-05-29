#!/bin/bash
# ABOUTME: Safe Alpine Linux WSL distribution builder using official minirootfs
# ABOUTME: Creates WSL-compliant Alpine distribution without dangerous bind mounts

set -euo pipefail

# Debug mode
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
DRY_RUN=${DRY_RUN:-0}

# Enable debug output if requested
if [ "$DEBUG" -eq 1 ]; then
    set -x
    export PS4='+ [${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:+${FUNCNAME[0]}()}] '
fi

# Default configuration
ALPINE_VERSION="${ALPINE_VERSION:-3.18.6}"
ARCH="${ARCH:-x86_64}"
BUILD_DIR="${BUILD_DIR:-alpine-wsl-build}"
ROOTFS_DIR="${ROOTFS_DIR:-$BUILD_DIR/rootfs}"
DISTRO_NAME="${DISTRO_NAME:-alpine-wsl}"
INSTALL_LOCATION="${INSTALL_LOCATION:-/tmp/wsl-alpine-install}"
OUTPUT_FILE="${OUTPUT_FILE:-alpine-wsl.tar.gz}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Progress indicator
progress() {
    echo -e "${BLUE}→${NC} $1"
    [ "$VERBOSE" -eq 1 ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROGRESS: $1" >&2
}

# Debug message
debug() {
    [ "$DEBUG" -eq 1 ] && echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
}

# Verbose message
verbose() {
    [ "$VERBOSE" -eq 1 ] && echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
}

# Success message
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Error message
error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Cleanup function
cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        warning "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
}

# Error handler
on_error() {
    local line=$1
    local code=${2:-1}
    local cmd="${BASH_COMMAND}"
    error "Build failed on line $line"
    error "Failed command: $cmd"
    error "Exit code: $code"
    
    if [ "$DEBUG" -eq 1 ]; then
        echo "Call stack:" >&2
        local frame=0
        while caller $frame; do
            ((frame++))
        done
    fi
    
    cleanup
    exit $code
}

trap 'on_error $LINENO $?' ERR

# Print banner
print_banner() {
    echo "╔══════════════════════════════════════════════╗"
    echo "║     Alpine Linux WSL Distribution Builder    ║"
    echo "║         (Safe MinirootFS Method)             ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    
    if [ "$DEBUG" -eq 1 ]; then
        echo "Debug mode: ENABLED"
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        echo "Verbose mode: ENABLED"
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Dry run mode: ENABLED (no changes will be made)"
    fi
    echo ""
}

# Check prerequisites
check_prerequisites() {
    progress "Checking prerequisites..."
    
    local missing=()
    
    for cmd in wget tar gzip sha256sum fakeroot; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    # Check for wsl.exe
    if ! command -v wsl.exe &> /dev/null; then
        error "wsl.exe not found. This script must be run from within WSL."
        return 1
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing required commands: ${missing[*]}"
        echo "Please install them and try again."
        return 1
    fi
    
    success "All prerequisites found"
}

# Download Alpine minirootfs
download_minirootfs() {
    progress "Downloading Alpine Linux minirootfs v${ALPINE_VERSION}..."
    
    local base_url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/${ARCH}"
    local filename="alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
    local checksum_file="${filename}.sha256"
    
    # Download minirootfs
    if [ -f "$filename" ]; then
        warning "Using existing $filename"
        verbose "File size: $(du -h "$filename" | cut -f1)"
    else
        verbose "Downloading from: $base_url/$filename"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY RUN] Would download: $base_url/$filename"
        else
            wget -q --show-progress "$base_url/$filename" || {
                error "Failed to download minirootfs"
                return 1
            }
        fi
    fi
    
    # Download and verify checksum
    progress "Verifying checksum..."
    wget -q "$base_url/$checksum_file" || {
        error "Failed to download checksum file"
        return 1
    }
    
    if sha256sum -c "$checksum_file" &> /dev/null; then
        success "Checksum verified"
    else
        error "Checksum verification failed"
        return 1
    fi
}

# Extract root filesystem
extract_rootfs() {
    progress "Extracting root filesystem..."
    
    debug "Creating rootfs directory: $ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would extract to: $ROOTFS_DIR"
        return 0
    fi
    
    verbose "Extracting $(tar -tzf "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz" | wc -l) files..."
    tar -xzf "alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz" -C "$ROOTFS_DIR" || {
        error "Failed to extract minirootfs"
        return 1
    }
    
    # Verify extraction
    if [ -d "$ROOTFS_DIR/etc" ] && [ -d "$ROOTFS_DIR/bin" ]; then
        success "Root filesystem extracted successfully"
    else
        error "Root filesystem extraction appears incomplete"
        return 1
    fi
}

# Configure APK repositories
configure_apk() {
    progress "Configuring APK repositories..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would configure APK repositories"
        return 0
    fi
    
    debug "Writing to $ROOTFS_DIR/etc/apk/repositories"
    cat > "$ROOTFS_DIR/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
    
    success "APK repositories configured"
}

# Configure WSL settings
configure_wsl() {
    progress "Configuring WSL settings..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would create WSL configuration files"
        return 0
    fi
    
    debug "Creating $ROOTFS_DIR/etc/wsl.conf"
    # Create wsl.conf
    cat > "$ROOTFS_DIR/etc/wsl.conf" << 'EOF'
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
    cat > "$ROOTFS_DIR/etc/wsl-distribution.conf" << 'EOF'
[oobe]
default = alpine-wsl
command = /etc/oobe.sh
EOF
    
    success "WSL configuration created"
}

# Create OOBE (Out-of-Box Experience) script
create_oobe_script() {
    progress "Creating first-boot setup script..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would create OOBE script"
        return 0
    fi
    
    debug "Creating $ROOTFS_DIR/etc/oobe.sh"
    cat > "$ROOTFS_DIR/etc/oobe.sh" << 'EOF'
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
echo "  wsl.exe --terminate $DISTRO_NAME"
echo "  wsl.exe -d $DISTRO_NAME"
echo ""
echo "Default credentials:"
echo "  Username: wsluser"
echo "  Password: wsluser"
echo ""
EOF
    
    chmod +x "$ROOTFS_DIR/etc/oobe.sh"
    success "OOBE script created"
}

# Set up basic system files
setup_system_files() {
    progress "Setting up basic system files..."
    
    # Ensure proper /etc/passwd entries
    cat > "$ROOTFS_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/ash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
EOF
    
    # Create essential directories
    mkdir -p "$ROOTFS_DIR"/{proc,sys,dev,tmp}
    chmod 1777 "$ROOTFS_DIR/tmp"
    
    # Remove resolv.conf to let WSL generate it
    rm -f "$ROOTFS_DIR/etc/resolv.conf"
    
    success "System files configured"
}

# Package the distribution
package_distribution() {
    progress "Packaging distribution..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would create distribution package: $BUILD_DIR/$OUTPUT_FILE"
        return 0
    fi
    
    verbose "Creating package script for fakeroot"
    # Create a script to run under fakeroot
    cat > "$BUILD_DIR/fakeroot-package.sh" << EOF
#!/bin/bash
set -e
cd "$ROOTFS_DIR"
tar --numeric-owner -c . | gzip --fast > "../$OUTPUT_FILE"
EOF
    chmod +x "$BUILD_DIR/fakeroot-package.sh"
    
    # Run packaging under fakeroot to preserve ownership
    fakeroot -- "$BUILD_DIR/fakeroot-package.sh" || {
        error "Failed to create distribution package"
        return 1
    }
    
    # Clean up
    rm -f "$BUILD_DIR/fakeroot-package.sh"
    
    # Verify the package
    local file_count=$(tar -tzf "$BUILD_DIR/$OUTPUT_FILE" | wc -l)
    if [ "$file_count" -gt 100 ]; then
        success "Distribution packaged successfully ($file_count files)"
    else
        error "Package appears incomplete (only $file_count files)"
        return 1
    fi
    
    # Create .wsl file for double-click install
    cp "$BUILD_DIR/$OUTPUT_FILE" "$BUILD_DIR/${OUTPUT_FILE%.tar.gz}.wsl"
    success "Created .wsl file for easy installation"
}

# Import into WSL
import_to_wsl() {
    progress "Importing distribution to WSL..."
    
    # Check if distribution already exists
    if wsl.exe --list --quiet | grep -q "^${DISTRO_NAME}$"; then
        warning "Distribution '$DISTRO_NAME' already exists"
        echo -n "Do you want to replace it? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            warning "Skipping WSL import"
            return 0
        fi
        
        progress "Unregistering existing distribution..."
        wsl.exe --unregister "$DISTRO_NAME"
    fi
    
    # Convert paths to Windows format
    local win_install_location="C:\\WSL\\$DISTRO_NAME"
    local win_tar_path=$(wslpath -w "$BUILD_DIR/$OUTPUT_FILE")
    
    # Import the distribution
    progress "Importing to WSL (this may take a moment)..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would import:"
        echo "  Name: $DISTRO_NAME"
        echo "  Location: $win_install_location"
        echo "  Archive: $win_tar_path"
        return 0
    fi
    
    debug "Running: wsl.exe --import '$DISTRO_NAME' '$win_install_location' '$win_tar_path' --version 2"
    if wsl.exe --import "$DISTRO_NAME" "$win_install_location" "$win_tar_path" --version 2; then
        success "Distribution imported successfully"
    else
        error "Failed to import distribution"
        return 1
    fi
    
    # Verify installation
    if wsl.exe --list --quiet | grep -q "^${DISTRO_NAME}$"; then
        success "Distribution '$DISTRO_NAME' is ready"
        echo ""
        echo "To complete setup, run:"
        echo "  wsl.exe -d $DISTRO_NAME"
        echo ""
        echo "The first boot will run the setup script automatically."
    else
        error "Distribution not found after import"
        return 1
    fi
}

# Run self-tests
run_tests() {
    echo "Running self-tests..."
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Prerequisites check
    echo -n "Test 1: Checking prerequisites... "
    if output=$(check_prerequisites 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Error: $output"
        ((tests_failed++))
    fi
    
    # Test 2: URL validation
    echo -n "Test 2: Validating Alpine mirror URLs... "
    local test_url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/${ARCH}/"
    if curl -Is --connect-timeout 5 --max-time 10 "$test_url" 2>/dev/null | head -n 1 | grep -q "200\|301\|302"; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC} (URL: $test_url)"
        ((tests_failed++))
    fi
    
    # Test 3: Build directory permissions
    echo -n "Test 3: Testing build directory permissions... "
    local test_dir="/tmp/alpine-wsl-test-$$"
    if mkdir -p "$test_dir" && touch "$test_dir/test" && rm -rf "$test_dir"; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((tests_failed++))
    fi
    
    # Test 4: WSL environment detection
    echo -n "Test 4: Detecting WSL environment... "
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        echo -e "${GREEN}PASS${NC} (WSL2 detected)"
        ((tests_passed++))
    elif command -v wsl.exe &>/dev/null; then
        echo -e "${GREEN}PASS${NC} (WSL1 detected)"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC} (Not running in WSL)"
        ((tests_failed++))
    fi
    
    # Test 5: Fakeroot functionality
    echo -n "Test 5: Testing fakeroot... "
    if echo 'touch /test 2>/dev/null && echo OK || echo FAIL' | fakeroot sh | grep -q OK; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((tests_failed++))
    fi
    
    echo ""
    echo "Test Results: ${GREEN}$tests_passed passed${NC}, ${RED}$tests_failed failed${NC}"
    
    if [ $tests_failed -gt 0 ]; then
        error "Some tests failed. Please fix the issues before proceeding."
        return 1
    fi
    
    success "All tests passed!"
    return 0
}

# Validate configuration
validate_config() {
    debug "Validating configuration..."
    
    # Check Alpine version format
    if ! [[ "$ALPINE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid Alpine version format: $ALPINE_VERSION"
        error "Expected format: X.Y.Z (e.g., 3.18.6)"
        return 1
    fi
    
    # Check architecture
    case "$ARCH" in
        x86_64|x86|aarch64|armhf|armv7|ppc64le|s390x)
            debug "Architecture $ARCH is supported"
            ;;
        *)
            error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    # Validate paths
    if [[ "$BUILD_DIR" = /* ]]; then
        warning "Using absolute path for BUILD_DIR: $BUILD_DIR"
    fi
    
    # Check distro name
    if [[ ! "$DISTRO_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        error "Invalid distribution name: $DISTRO_NAME"
        error "Name must start with a letter and contain only alphanumeric characters, hyphens, and underscores"
        return 1
    fi
    
    verbose "Configuration validated successfully"
    return 0
}

# Main build process
main() {
    print_banner
    
    # Parse command line arguments
    local skip_import=false
    local run_tests=false
    local show_help=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-import)
                skip_import=true
                shift
                ;;
            --test)
                run_tests=true
                shift
                ;;
            --debug)
                DEBUG=1
                set -x
                shift
                ;;
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help=true
                shift
                ;;
        esac
    done
    
    # Show help if requested
    if [ "$show_help" = true ]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --no-import    Build the distribution but don't import to WSL"
        echo "  --test         Run self-tests and exit"
        echo "  --debug        Enable debug output (set -x)"
        echo "  --verbose, -v  Enable verbose output"
        echo "  --dry-run      Show what would be done without making changes"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  ALPINE_VERSION  Alpine version (default: 3.18.6)"
        echo "  ARCH            Architecture (default: x86_64)"
        echo "  BUILD_DIR       Build directory (default: alpine-wsl-build)"
        echo "  DISTRO_NAME     WSL distribution name (default: alpine-wsl)"
        echo "  DEBUG           Enable debug mode (0/1)"
        echo "  VERBOSE         Enable verbose mode (0/1)"
        echo "  DRY_RUN         Enable dry run mode (0/1)"
        return 0
    fi
    
    # Run tests if requested
    if [ "$run_tests" = true ]; then
        run_tests
        return $?
    fi
    
    # Validate configuration
    validate_config || return 1
    
    # Check prerequisites
    check_prerequisites
    
    # Create build directory
    progress "Creating build directory..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Download minirootfs
    download_minirootfs
    
    # Extract root filesystem
    extract_rootfs
    
    # Configure the system
    configure_apk
    configure_wsl
    create_oobe_script
    setup_system_files
    
    # Package the distribution
    package_distribution
    
    # Import to WSL
    if [ "$skip_import" = false ]; then
        import_to_wsl
    else
        warning "Skipping WSL import (--no-import flag)"
    fi
    
    # Clean up
    cd - > /dev/null
    success "Build complete!"
    
    echo ""
    echo "Distribution files saved in: $BUILD_DIR/"
    echo "  - $OUTPUT_FILE (WSL import format)"
    echo "  - ${OUTPUT_FILE%.tar.gz}.wsl (double-click install)"
    
    if [ "$skip_import" = true ]; then
        echo ""
        echo "To import manually, run:"
        echo "  wsl.exe --import <name> C:\\WSL\\<name> \"$(wslpath -w $BUILD_DIR/$OUTPUT_FILE)\" --version 2"
    fi
}

# Run main function
main "$@"
exit $?