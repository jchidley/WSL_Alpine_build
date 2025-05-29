#!/bin/sh
# Claude Code module for Alpine WSL build
# This can be sourced during the build process or run as part of oobe.sh

# Function to add Claude Code to the first-boot setup
setup_claude_code_firstboot() {
    cat >> /root/oobe.sh << 'EOF'

# Claude Code Installation (Optional)
if [ -n "$INSTALL_CLAUDE_CODE" ]; then
    echo "🤖 Installing Claude Code..."
    
    # Install Node.js and npm
    apk add --no-cache nodejs npm
    
    # Install Claude Code globally
    npm install -g @anthropic-ai/claude-code
    
    # Create basic configuration
    mkdir -p ~/.config/claude-code
    cat > ~/.config/claude-code/config.json << 'EOFCONFIG'
{
    "telemetry": {
        "enabled": false
    },
    "editor": {
        "default": "hx"
    }
}
EOFCONFIG
    
    echo "✅ Claude Code installed. Set ANTHROPIC_API_KEY to use."
fi
EOF
}

# Function to add Claude Code option to .env.example
add_claude_code_env_option() {
    if [ -f .env.example ]; then
        echo "" >> .env.example
        echo "# Claude Code Installation (optional)" >> .env.example
        echo "# Set to 'true' to install Claude Code during first boot" >> .env.example
        echo "# INSTALL_CLAUDE_CODE=true" >> .env.example
        echo "" >> .env.example
        echo "# Anthropic API Key (optional)" >> .env.example
        echo "# Set this to automatically configure Claude Code" >> .env.example
        echo "# ANTHROPIC_API_KEY=sk-ant-..." >> .env.example
    fi
}

# If sourced, export functions
if [ "${0##*/}" != "claude-code-setup.sh" ]; then
    # Script is being sourced
    return 0
fi

# If run directly, show usage
echo "Claude Code Module Setup"
echo "======================="
echo ""
echo "This module can be integrated into the Alpine WSL build process."
echo ""
echo "To use:"
echo "1. Source this file in wsl-alpine-build.sh"
echo "2. Call setup_claude_code_firstboot() to add to oobe.sh"
echo "3. Call add_claude_code_env_option() to update .env.example"
echo ""
echo "Or manually install Claude Code after build with:"
echo "  ./wsl-alpine-claude-code.sh"