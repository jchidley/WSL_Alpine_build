#!/bin/bash
# ABOUTME: Claude Code OOBE module for Alpine WSL builds
# ABOUTME: Source this file to add Claude Code installation to your OOBE script

# Function to add Claude Code installation to OOBE
add_claude_code_to_oobe() {
    local oobe_content="$1"
    
    # Insert Claude Code installation before the cleanup section
    cat << 'CLAUDE_CODE_SECTION'

# Install Node.js and npm for Claude Code
echo "→ Installing Node.js and npm..."
apk add --no-cache nodejs npm

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

# Add npm global bin to PATH in bashrc
echo '' >> /home/wsluser/.bashrc
echo '# Add npm global bin to PATH' >> /home/wsluser/.bashrc
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/wsluser/.bashrc

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
cat >> /home/wsluser/.bashrc << 'BASHRC2'

# Show Claude Code welcome message on first login
if [ -f ~/.claude-welcome ]; then
    cat ~/.claude-welcome
    rm ~/.claude-welcome
fi
BASHRC2

CLAUDE_CODE_SECTION
}

# Function to inject Claude Code into an existing OOBE script file
inject_claude_code_into_oobe() {
    local oobe_file="$1"
    local temp_file="${oobe_file}.tmp"
    
    if [ ! -f "$oobe_file" ]; then
        echo "Error: OOBE file not found: $oobe_file"
        return 1
    fi
    
    # Read the file and inject Claude Code section before cleanup
    awk '
        /^# Clean up/ || /^echo "→ Cleaning up..."/ {
            print "'"$(add_claude_code_to_oobe | sed "s/'/'\\\\''/g")"'"
            print ""
        }
        { print }
    ' "$oobe_file" > "$temp_file"
    
    mv "$temp_file" "$oobe_file"
    echo "Claude Code installation added to OOBE script"
}

# Function to add Claude Code packages to the package list
add_claude_code_packages() {
    echo "nodejs npm"
}

# Function to check if Claude Code should be installed
should_install_claude_code() {
    # Check environment variable, default to true
    [ "${INSTALL_CLAUDE_CODE:-true}" = "true" ]
}

# Function to add Claude Code option to build configuration
add_claude_code_build_option() {
    cat << 'EOF'
# Claude Code Installation
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-true}"  # Set to false to skip
EOF
}

# Export functions for use in other scripts
export -f add_claude_code_to_oobe
export -f inject_claude_code_into_oobe
export -f add_claude_code_packages
export -f should_install_claude_code
export -f add_claude_code_build_option