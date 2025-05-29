#!/usr/bin/env bash
# Install Claude Code in Alpine WSL distribution

set -e

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-functions.sh"

# Default values
WSL_DISTRIBUTION_NAME="${WSL_DISTRIBUTION_NAME:-alp2}"
INSTALL_METHOD="${INSTALL_METHOD:-native}"  # native or docker
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-latest}"

# Check if running inside WSL
if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo "❌ This script must be run inside a WSL distribution"
    exit 1
fi

# Function to check if we're in the correct Alpine distribution
check_alpine_distribution() {
    if [ ! -f /etc/alpine-release ]; then
        echo "❌ This script must be run inside an Alpine Linux distribution"
        exit 1
    fi
    
    local alpine_version=$(cat /etc/alpine-release)
    echo "✅ Running in Alpine Linux $alpine_version"
}

# Function to install Node.js and npm
install_nodejs() {
    echo "📦 Installing Node.js and npm..."
    
    # Update package index
    apk update
    
    # Install Node.js and npm
    apk add --no-cache nodejs npm
    
    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    
    echo "✅ Node.js $node_version installed"
    echo "✅ npm $npm_version installed"
}

# Function to install Claude Code natively
install_claude_code_native() {
    echo "🚀 Installing Claude Code natively..."
    
    # Install globally using npm
    if [ "$CLAUDE_CODE_VERSION" = "latest" ]; then
        npm install -g @anthropic-ai/claude-code
    else
        npm install -g "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION"
    fi
    
    # Verify installation
    if command -v claude &>/dev/null; then
        claude_version=$(claude --version 2>&1 || echo "version unknown")
        echo "✅ Claude Code installed: $claude_version"
    else
        echo "❌ Claude Code installation failed"
        exit 1
    fi
}

# Function to install Claude Code in Docker
install_claude_code_docker() {
    echo "🐳 Setting up Claude Code in Docker..."
    
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        echo "   Run: apk add docker docker-cli docker-compose"
        echo "   Then: rc-update add docker boot && service docker start"
        exit 1
    fi
    
    # Check if Docker service is running
    if ! docker info &>/dev/null; then
        echo "⚠️  Docker service is not running. Starting Docker..."
        service docker start || {
            echo "❌ Failed to start Docker service"
            exit 1
        }
    fi
    
    # Create Dockerfile for Claude Code
    cat > /tmp/claude-code.Dockerfile << 'EOF'
FROM node:20-alpine

# Install additional tools that Claude Code might need
RUN apk add --no-cache \
    git \
    bash \
    curl \
    make \
    g++ \
    python3

# Create a non-root user
RUN adduser -D -s /bin/bash claude

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory
RUN mkdir -p /workspace && chown claude:claude /workspace

# Switch to non-root user
USER claude
WORKDIR /workspace

# Set up environment
ENV NODE_ENV=production

# Entry point
ENTRYPOINT ["claude"]
EOF

    # Build Docker image
    echo "🔨 Building Claude Code Docker image..."
    docker build -t claude-code:alpine -f /tmp/claude-code.Dockerfile /tmp/
    
    # Create wrapper script
    cat > /usr/local/bin/claude-docker << 'EOF'
#!/bin/sh
# Wrapper script to run Claude Code in Docker

# Determine workspace directory
WORKSPACE="${CLAUDE_WORKSPACE:-$(pwd)}"

# Run Claude Code in Docker with proper mounts and permissions
docker run -it --rm \
    -v "$WORKSPACE:/workspace" \
    -v "$HOME/.config:/home/claude/.config" \
    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" \
    -e "CLAUDE_CODE_DANGEROUSLY_SKIP_PERMISSIONS=${CLAUDE_CODE_DANGEROUSLY_SKIP_PERMISSIONS}" \
    --network="${CLAUDE_NETWORK:-bridge}" \
    claude-code:alpine "$@"
EOF

    chmod +x /usr/local/bin/claude-docker
    
    # Create alias for convenience
    echo "alias claude='claude-docker'" >> /etc/profile.d/claude.sh
    
    echo "✅ Claude Code Docker setup complete"
    echo "   Use 'claude-docker' or 'claude' to run Claude Code in Docker"
    
    # Clean up
    rm -f /tmp/claude-code.Dockerfile
}

# Function to configure Claude Code
configure_claude_code() {
    echo "⚙️  Configuring Claude Code..."
    
    # Create config directory
    mkdir -p ~/.config/claude-code
    
    # Create basic configuration
    cat > ~/.config/claude-code/config.json << EOF
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
EOF

    echo "✅ Basic configuration created"
    
    # Show authentication instructions
    cat << EOF

🔑 Authentication Setup:

Option 1: Claude Max Subscription
  Run: claude login
  Then follow the browser authentication flow

Option 2: API Key
  Export your API key:
  export ANTHROPIC_API_KEY="your-api-key-here"
  
  To make it permanent, add to ~/.profile:
  echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.profile

EOF
}

# Function to create uninstall script
create_uninstall_script() {
    cat > /usr/local/bin/claude-uninstall << 'EOF'
#!/bin/sh
# Uninstall Claude Code from Alpine WSL

echo "🗑️  Uninstalling Claude Code..."

# Check installation method
if command -v claude &>/dev/null && [ -f /usr/local/lib/node_modules/@anthropic-ai/claude-code/package.json ]; then
    # Native installation
    echo "Removing native Claude Code installation..."
    npm uninstall -g @anthropic-ai/claude-code
fi

if [ -f /usr/local/bin/claude-docker ]; then
    # Docker installation
    echo "Removing Docker Claude Code setup..."
    rm -f /usr/local/bin/claude-docker
    rm -f /etc/profile.d/claude.sh
    docker rmi claude-code:alpine 2>/dev/null || true
fi

# Remove configuration
if [ -d ~/.config/claude-code ]; then
    echo "Remove Claude Code configuration? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        rm -rf ~/.config/claude-code
    fi
fi

echo "✅ Claude Code uninstalled"
EOF

    chmod +x /usr/local/bin/claude-uninstall
    echo "✅ Created uninstall script: /usr/local/bin/claude-uninstall"
}

# Main installation flow
main() {
    echo "🎯 Claude Code Installation for Alpine WSL"
    echo "========================================="
    
    # Check prerequisites
    check_alpine_distribution
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                INSTALL_METHOD="docker"
                shift
                ;;
            --native)
                INSTALL_METHOD="native"
                shift
                ;;
            --version)
                CLAUDE_CODE_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
    --native    Install Claude Code directly (default)
    --docker    Install Claude Code in Docker container
    --version   Specify Claude Code version (default: latest)
    --help      Show this help message

Environment Variables:
    ANTHROPIC_API_KEY    Your Anthropic API key
    CLAUDE_WORKSPACE     Default workspace for Docker mode

Examples:
    # Install natively (default)
    $0

    # Install in Docker
    $0 --docker

    # Install specific version
    $0 --version 1.2.3
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Install Node.js if not present
    if ! command -v node &>/dev/null; then
        install_nodejs
    else
        echo "✅ Node.js already installed: $(node --version)"
    fi
    
    # Install Claude Code based on method
    case $INSTALL_METHOD in
        native)
            install_claude_code_native
            ;;
        docker)
            install_claude_code_docker
            ;;
        *)
            echo "❌ Unknown installation method: $INSTALL_METHOD"
            exit 1
            ;;
    esac
    
    # Configure Claude Code
    configure_claude_code
    
    # Create uninstall script
    create_uninstall_script
    
    echo ""
    echo "🎉 Claude Code installation complete!"
    echo ""
    echo "Next steps:"
    if [ "$INSTALL_METHOD" = "native" ]; then
        echo "  1. Set up authentication (see instructions above)"
        echo "  2. Run: claude --help"
        echo "  3. Start coding with: claude"
    else
        echo "  1. Set up authentication (see instructions above)"
        echo "  2. Run: claude --help"
        echo "  3. Start coding with: claude (runs in Docker)"
        echo ""
        echo "Docker-specific options:"
        echo "  - Set CLAUDE_WORKSPACE to change default workspace"
        echo "  - Set CLAUDE_NETWORK to 'none' for offline mode"
    fi
    echo ""
    echo "To uninstall later, run: claude-uninstall"
}

# Run main function
main "$@"