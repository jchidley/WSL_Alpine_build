#!/bin/bash
# ABOUTME: Alpine Linux WSL builder with integrated Claude Code installation
# ABOUTME: Based on wsl-alpine-build-minirootfs.sh with Claude Code support

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the original minirootfs build script functions
source "${SCRIPT_DIR}/wsl-alpine-build-minirootfs.sh"

# Override the create_oobe_script function to include Claude Code
create_oobe_script() {
    progress "Creating first-boot setup script with Claude Code..."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would create OOBE script with Claude Code"
        return 0
    fi
    
    debug "Creating $ROOTFS_DIR/etc/oobe.sh"
    cat > "$ROOTFS_DIR/etc/oobe.sh" << 'EOF'
#!/bin/sh
# Alpine WSL Out-of-Box Experience with Claude Code

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

# Install Node.js and npm for Claude Code
echo "→ Installing Node.js and npm..."
apk add --no-cache nodejs npm

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

# Add npm global bin to PATH
export PATH="$HOME/.npm-global/bin:$PATH"
BASHRC

# Fix WSL interop
chmod 755 /

# OpenRC configuration for WSL
mkdir -p /etc/conf.d
cat > /etc/conf.d/devfs << 'DEVFS'
# Use devtmpfs for /dev
devtmpfs_mount="YES"
DEVFS

# Set WSL-specific hostname
hostname alpine-wsl

# Configure WSL integration
cat > /etc/wsl.conf << 'WSLCONF'
[boot]
systemd = false

[user]
default = wsluser
WSLCONF

# Install Claude Code as the default user
echo "→ Installing Claude Code..."
su - wsluser -c "npm config set prefix ~/.npm-global"
su - wsluser -c "npm install -g @anthropic-ai/claude-code"

# Create Claude Code configuration
mkdir -p /home/wsluser/.config/claude-code
cat > /home/wsluser/.config/claude-code/config.json << 'CLAUDECONFIG'
{
    "telemetry": {
        "enabled": false
    },
    "editor": {
        "default": "hx"
    },
    "git": {
        "autoCommit": false
    }
}
CLAUDECONFIG
chown -R wsluser:wsluser /home/wsluser/.config/claude-code

# Create a welcome message with Claude Code info
cat > /home/wsluser/.claude-welcome << 'WELCOME'
═══════════════════════════════════════════════════════════════
  Claude Code is installed! 🎉
═══════════════════════════════════════════════════════════════

To get started:
  1. Authenticate: claude login
  2. Start coding: claude

For headless/CI usage: claude --dangerously-skip-permissions

Configuration: ~/.config/claude-code/config.json
Uninstall: npm uninstall -g @anthropic-ai/claude-code
═══════════════════════════════════════════════════════════════
WELCOME
chown wsluser:wsluser /home/wsluser/.claude-welcome

# Add to bashrc to show on first login
cat >> /home/wsluser/.bashrc << 'BASHRC'

# Show Claude Code welcome message on first login
if [ -f ~/.claude-welcome ]; then
    cat ~/.claude-welcome
    rm ~/.claude-welcome
fi
BASHRC

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
echo "Claude Code will be available after restart!"
echo ""
EOF
    
    chmod +x "$ROOTFS_DIR/etc/oobe.sh"
    success "OOBE script with Claude Code created"
}

# Add new environment variable for Claude Code
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-true}"

# Update usage to include Claude Code option
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
    --no-claude         Skip Claude Code installation

Environment variables:
    ALPINE_VERSION      Alpine version to use
    ARCH                Architecture (x86_64, aarch64, etc.)
    DISTRO_NAME         WSL distribution name
    BUILD_DIR           Build directory
    OUTPUT_FILE         Output tarball name
    INSTALL_CLAUDE_CODE Install Claude Code (true/false, default: true)
    DEBUG               Enable debug mode (0/1)
    VERBOSE             Enable verbose mode (0/1)
    DRY_RUN             Enable dry-run mode (0/1)

Example:
    $0 --verbose --name alpine-dev --version 3.19.0

This version includes Claude Code installation by default.
To skip Claude Code installation, use --no-claude
EOF
}

# Override parse_args to handle --no-claude
original_parse_args=$(declare -f parse_args)
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-claude)
                INSTALL_CLAUDE_CODE=false
                shift
                ;;
            *)
                # Call original argument parsing for other options
                set -- "$1"
                eval "${original_parse_args#*\{}"
                return
                ;;
        esac
    done
}

# Show Claude Code status in build summary
original_show_summary=$(declare -f show_summary || echo "show_summary() { :; }")
show_summary() {
    eval "${original_show_summary#*\{}" 2>/dev/null || true
    echo "Claude Code:      ${INSTALL_CLAUDE_CODE}"
}

# Copy the Claude Code installation script to the rootfs
copy_claude_script() {
    if [ "$INSTALL_CLAUDE_CODE" = "true" ] && [ -f "$SCRIPT_DIR/wsl-alpine-claude-code.sh" ]; then
        progress "Copying Claude Code installation script..."
        cp "$SCRIPT_DIR/wsl-alpine-claude-code.sh" "$ROOTFS_DIR/usr/local/bin/claude-install"
        chmod +x "$ROOTFS_DIR/usr/local/bin/claude-install"
        success "Claude Code installation script copied"
    fi
}

# Override the main build process to include Claude script copy
original_main=$(declare -f main)
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Show banner
    cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║  Alpine Linux WSL Builder with Claude Code            ║
║  Safe minirootfs-based approach                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    
    # Validate environment
    validate_environment
    
    # Show configuration
    show_summary
    
    # Create build directory
    progress "Creating build directory..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Download and verify minirootfs
    download_minirootfs
    verify_minirootfs
    
    # Extract and configure
    extract_rootfs
    configure_apk
    configure_wsl
    create_oobe_script
    setup_system_files
    copy_claude_script  # Add Claude script copy
    
    # Create WSL distribution archive
    create_wsl_archive
    
    # Install in WSL
    if [ "${SKIP_INSTALL:-0}" -eq 0 ]; then
        install_wsl_distro
    fi
    
    success "Build complete!"
    
    if [ "${SKIP_INSTALL:-0}" -eq 0 ]; then
        cat << EOF

Your Alpine WSL distribution '$DISTRO_NAME' has been created!
Claude Code will be installed during first boot.

To start using it:
  wsl.exe -d $DISTRO_NAME

First login credentials:
  Username: root (for initial setup)
  
After first boot:
  Username: wsluser
  Password: wsluser

EOF
    else
        echo ""
        echo "Distribution archive created: $OUTPUT_FILE"
        echo "To install: wsl.exe --import $DISTRO_NAME <install-location> $OUTPUT_FILE"
    fi
}

# Run the build
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi