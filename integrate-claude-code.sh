#!/bin/bash
# ABOUTME: Example script showing how to integrate Claude Code into existing Alpine WSL builds
# ABOUTME: This demonstrates the modular approach for adding Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the Claude Code module
source "$SCRIPT_DIR/modules/claude-code-oobe.sh"

echo "Claude Code Integration Helper"
echo "=============================="
echo ""
echo "This script helps integrate Claude Code into your Alpine WSL build process."
echo ""

# Option 1: Quick patch existing build
patch_existing_build() {
    echo "Option 1: Patching existing wsl-alpine-build-minirootfs.sh"
    echo "This will modify the script to include Claude Code installation"
    echo ""
    
    # Create a backup
    cp "$SCRIPT_DIR/wsl-alpine-build-minirootfs.sh" "$SCRIPT_DIR/wsl-alpine-build-minirootfs.sh.backup"
    
    # Create a wrapper script that sources the original and adds Claude Code
    cat > "$SCRIPT_DIR/wsl-alpine-build-minirootfs-claude.sh" << 'EOF'
#!/bin/bash
# Alpine WSL build with Claude Code integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the Claude Code module
source "$SCRIPT_DIR/modules/claude-code-oobe.sh"

# Source the original build script
source "$SCRIPT_DIR/wsl-alpine-build-minirootfs.sh"

# Override the create_oobe_script function
original_create_oobe_script=$(declare -f create_oobe_script)
create_oobe_script() {
    # Call the original function
    eval "${original_create_oobe_script#*{}"
    
    # If Claude Code installation is enabled, inject it into the OOBE script
    if should_install_claude_code; then
        inject_claude_code_into_oobe "$ROOTFS_DIR/etc/oobe.sh"
    fi
}

# Add Claude Code status to summary
original_show_summary=$(declare -f show_summary 2>/dev/null || echo "")
if [ -n "$original_show_summary" ]; then
    show_summary() {
        eval "${original_show_summary#*{}"
        echo "Claude Code:      ${INSTALL_CLAUDE_CODE:-true}"
    }
fi

# Run the main function if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
    
    chmod +x "$SCRIPT_DIR/wsl-alpine-build-minirootfs-claude.sh"
    
    echo "✅ Created: wsl-alpine-build-minirootfs-claude.sh"
    echo "   This is a wrapper that adds Claude Code to your existing build"
    echo ""
    echo "To use: ./wsl-alpine-build-minirootfs-claude.sh [options]"
    echo "To skip Claude Code: INSTALL_CLAUDE_CODE=false ./wsl-alpine-build-minirootfs-claude.sh"
}

# Option 2: Create a post-install script
create_post_install() {
    echo "Option 2: Creating post-install script"
    echo "This creates a script to run inside Alpine after WSL installation"
    echo ""
    
    cat > "$SCRIPT_DIR/claude-code-post-install.sh" << 'EOF'
#!/bin/ash
# Post-install script to add Claude Code to existing Alpine WSL

echo "Installing Claude Code in Alpine WSL..."

# Update and install Node.js
apk update
apk add --no-cache nodejs npm

# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Create configuration
mkdir -p ~/.config/claude-code
cat > ~/.config/claude-code/config.json << 'CONFIG'
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
CONFIG

# Add npm global bin to PATH
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc

echo ""
echo "✅ Claude Code installed!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell or run: source ~/.bashrc"
echo "  2. Authenticate: claude login"
echo "  3. Start coding: claude"
EOF
    
    chmod +x "$SCRIPT_DIR/claude-code-post-install.sh"
    
    echo "✅ Created: claude-code-post-install.sh"
    echo "   Copy this to your Alpine WSL and run it to install Claude Code"
    echo ""
    echo "To use:"
    echo "  1. wsl.exe -d <your-alpine-distro>"
    echo "  2. Copy and run: ./claude-code-post-install.sh"
}

# Option 3: Show manual integration
show_manual_integration() {
    echo "Option 3: Manual Integration Guide"
    echo "=================================="
    echo ""
    echo "To manually add Claude Code to your build process:"
    echo ""
    echo "1. Add to your package list:"
    echo "   apk add --no-cache nodejs npm"
    echo ""
    echo "2. Add to your OOBE or setup script:"
    echo "   npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "3. Configure Claude Code:"
    echo "   mkdir -p ~/.config/claude-code"
    echo "   # Create config.json with editor preferences"
    echo ""
    echo "4. Add to PATH in .bashrc:"
    echo "   export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
}

# Main menu
echo "Choose an integration method:"
echo "1. Patch existing build script (recommended)"
echo "2. Create post-install script"
echo "3. Show manual integration steps"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        patch_existing_build
        ;;
    2)
        create_post_install
        ;;
    3)
        show_manual_integration
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Integration complete!"