#!/usr/bin/env bash
# Development module installation script

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"

# Check ROOTFS_DIR is set
if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing development module..."

# Create package installation script for OOBE
log_progress "Creating development package installation script..."
mkdir -p "$ROOTFS_DIR/etc/oobe.d"

cat > "$ROOTFS_DIR/etc/oobe.d/20-development-packages.sh" << 'EOF'
#!/bin/sh
# Install development packages on first boot

echo "Installing minimal development tools..."

# Install development packages
DEV_PACKAGES="helix fd bat zoxide ripgrep"
if ! apk add --no-cache $DEV_PACKAGES; then
    echo "ERROR: Failed to install development packages" >&2
    exit 1
fi

echo "✓ Development packages installed successfully"

# Try to install tree-sitter grammars for Helix
echo "Installing Helix syntax highlighting..."
GRAMMARS="tree-sitter-bash tree-sitter-c tree-sitter-cpp tree-sitter-css tree-sitter-go tree-sitter-html tree-sitter-javascript tree-sitter-json tree-sitter-python tree-sitter-rust tree-sitter-typescript tree-sitter-yaml"

for grammar in $GRAMMARS; do
    if apk add --no-cache "$grammar" 2>/dev/null; then
        echo "  ✓ Installed $grammar"
    fi
done

echo "✓ Helix syntax highlighting setup complete"
EOF

chmod +x "$ROOTFS_DIR/etc/oobe.d/20-development-packages.sh"

# Configure Helix
log_progress "Configuring Helix editor..."
mkdir -p "$ROOTFS_DIR/home/wsluser/.config/helix"
cat > "$ROOTFS_DIR/home/wsluser/.config/helix/config.toml" << 'EOF'
theme = "gruvbox_dark_hard"

[editor]
line-number = "relative"
mouse = true
rulers = [80, 120]
auto-save = true
completion-trigger-len = 2
idle-timeout = 250
preview-completion-insert = false

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.file-picker]
hidden = false
follow-links = true
deduplicate-links = true
parents = true
ignore = true
git-ignore = true
git-global = true
git-exclude = true

[editor.indent-guides]
render = true
character = "╎"
skip-levels = 1

[editor.statusline]
left = ["mode", "spinner", "version-control", "file-name", "file-modification-indicator"]
center = ["position", "position-percentage", "total-line-numbers"]
right = ["diagnostics", "selections", "register", "file-encoding", "file-line-ending", "file-type"]

[editor.lsp]
display-messages = true
display-inlay-hints = true

[editor.whitespace.render]
space = "none"
tab = "all"
newline = "none"

[editor.whitespace.characters]
space = "·"
nbsp = "⍽"
tab = "→"
newline = "⏎"
tabpad = "·"

[keys.normal]
space.w = ":w"
space.q = ":q"
EOF

# Copy Helix config to root user
cp -r "$ROOTFS_DIR/home/wsluser/.config/helix" "$ROOTFS_DIR/root/.config/"

# Add shell configuration for development tools
cat >> "$ROOTFS_DIR/home/wsluser/.bashrc" << 'EOF'

# Development tools configuration
if [ -f /etc/profile.d/pi-agent-env.sh ]; then
    . /etc/profile.d/pi-agent-env.sh
fi

export EDITOR=hx
export VISUAL=hx
export PAGER="bat --style=plain"

# Initialize zoxide
eval "$(zoxide init bash)"

# Bat configuration
export BAT_THEME="gruvbox-dark"

# Aliases for modern tools
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias vim='hx'
alias vi='hx'

# Development functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}
EOF

# Create development info script
cat > "$ROOTFS_DIR/etc/development-info" << 'EOF'
#!/bin/bash
# Display development tools information

echo "╔══════════════════════════════════════════════╗"
echo "║      Development Tools Module (Minimal)      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Editor:"
echo "  • Helix (hx) - Modern terminal editor"
echo ""
echo "Modern CLI Tools:"
echo "  • fd - Fast file finder (replaces find)"
echo "  • bat - Cat with syntax highlighting"
echo "  • ripgrep (rg) - Fast grep replacement"
echo "  • zoxide - Smart cd command"
echo ""
echo "Useful aliases:"
echo "  • cat → bat"
echo "  • find → fd"
echo "  • grep → rg"
echo "  • vim/vi → hx"
echo ""
echo "Custom functions:"
echo "  • mkcd - Make directory and cd into it"
echo ""
EOF
chmod +x "$ROOTFS_DIR/etc/development-info"

# Add to login message
cat > "$ROOTFS_DIR/etc/development-motd" << 'EOF'

Development tools installed! Run:
  development-info - Show available tools and aliases
  hx              - Launch Helix editor

EOF

log_success "Development module installed successfully"