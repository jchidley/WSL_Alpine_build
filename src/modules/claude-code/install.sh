#!/usr/bin/env bash
# Claude Code module installation script

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"
# shellcheck source=src/lib/package.sh
source "${PROJECT_ROOT}/src/lib/package.sh"

# Check ROOTFS_DIR is set
if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing claude-code module..."

# Install Node.js and npm
log_progress "Installing Node.js and npm..."
if ! install_packages "$ROOTFS_DIR" nodejs npm git curl bash; then
    log_error "Failed to install Node.js packages"
    exit 1
fi

# Create Claude Code installation script
log_progress "Creating Claude Code installation script..."
cat > "$ROOTFS_DIR/usr/local/bin/install-claude-code" << 'EOF'
#!/bin/bash
# Install Claude Code CLI

set -e

echo "Installing Claude Code CLI..."

# Check if already installed
if command -v claude >/dev/null 2>&1; then
    echo "Claude Code is already installed"
    claude --version
    exit 0
fi

# Install Claude Code globally
echo "Installing @anthropic-ai/claude-code..."
npm install -g @anthropic-ai/claude-code

# Create configuration directory
mkdir -p ~/.config/claude-code

# Create basic configuration if it doesn't exist
if [ ! -f ~/.config/claude-code/config.json ]; then
    cat > ~/.config/claude-code/config.json << 'EOFCONFIG'
{
    "telemetry": {
        "enabled": false
    },
    "editor": {
        "default": "hx"
    },
    "terminal": {
        "colorScheme": "gruvbox-dark"
    }
}
EOFCONFIG
fi

echo ""
echo "✓ Claude Code installed successfully!"
echo ""
echo "To get started:"
echo "  1. Run 'claude login' to authenticate"
echo "  2. Use 'claude --help' to see available commands"
echo ""
echo "For Docker/CI environments:"
echo "  Use 'claude --dangerously-skip-permissions' flag"
echo ""
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/install-claude-code"

# Create Claude Code Docker wrapper
log_progress "Creating Claude Code Docker wrapper..."
cat > "$ROOTFS_DIR/usr/local/bin/claude-docker" << 'EOF'
#!/bin/bash
# Run Claude Code in Docker container with proper permissions

# Check if Claude Code is installed
if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code not installed. Run: install-claude-code"
    exit 1
fi

# Check if running in Docker
if [ -f /.dockerenv ]; then
    # In Docker, use the skip permissions flag
    exec claude --dangerously-skip-permissions "$@"
else
    # Not in Docker, run normally
    exec claude "$@"
fi
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/claude-docker"

# Add Claude Code configuration to user bashrc
cat >> "$ROOTFS_DIR/home/wsluser/.bashrc" << 'EOF'

# Claude Code configuration
export ANTHROPIC_LOG_LEVEL="${ANTHROPIC_LOG_LEVEL:-error}"

# Claude Code aliases
alias claude-login='claude login'
alias claude-help='claude --help'

# Auto-install Claude Code on first use
claude() {
    if ! command -v claude >/dev/null 2>&1; then
        echo "Claude Code not found. Installing..."
        install-claude-code
    fi
    command claude "$@"
}
EOF

# Create Claude Code info script
cat > "$ROOTFS_DIR/etc/claude-code-info" << 'EOF'
#!/bin/bash
# Display Claude Code information

echo "╔══════════════════════════════════════════════╗"
echo "║          Claude Code CLI Module              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Claude Code provides AI assistance for:"
echo "  • Code generation and modification"
echo "  • Debugging and problem-solving"
echo "  • Documentation and explanations"
echo "  • Refactoring and optimization"
echo ""
echo "Installation:"
echo "  Run: install-claude-code"
echo ""
echo "Usage:"
echo "  claude login              - Authenticate with Claude"
echo "  claude new <project>      - Create new project"
echo "  claude chat               - Start interactive session"
echo "  claude --help             - Show all commands"
echo ""
echo "Docker/CI Usage:"
echo "  Use claude-docker wrapper or add flag:"
echo "  claude --dangerously-skip-permissions"
echo ""
echo "Configuration:"
echo "  Config file: ~/.config/claude-code/config.json"
echo "  API key: Set ANTHROPIC_API_KEY environment variable"
echo ""
EOF
chmod +x "$ROOTFS_DIR/etc/claude-code-info"

# Add to login message
cat > "$ROOTFS_DIR/etc/claude-code-motd" << 'EOF'

Claude Code CLI available! Run:
  install-claude-code  - Install Claude Code
  claude-code-info     - Show Claude Code information

EOF

# Create environment file template
cat > "$ROOTFS_DIR/etc/claude-code.env.example" << 'EOF'
# Claude Code Environment Variables

# Anthropic API Key (required for API access)
# ANTHROPIC_API_KEY=sk-ant-...

# Log level (error, warn, info, debug)
ANTHROPIC_LOG_LEVEL=error

# Claude Code configuration directory
# CLAUDE_CODE_CONFIG_DIR=$HOME/.config/claude-code

# Default editor for Claude Code
# EDITOR=hx

# Enable experimental features
# CLAUDE_CODE_EXPERIMENTAL=false
EOF

log_success "Claude Code module installed successfully"