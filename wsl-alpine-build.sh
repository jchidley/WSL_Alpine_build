#!/usr/bin/env bash
# WSL Alpine Build Script
# 
# Creates a customized Alpine Linux distribution for WSL with:
# - Helix editor with syntax highlighting
# - Modern command-line tools (fd, bat, zoxide, fzf)
# - Docker support
# - Terminal styling with Gruvbox Dark theme
#
# Usage:
#   1. Create a .env file with configuration (or use defaults)
#   2. Run ./wsl-alpine-build.sh
#   3. Follow on-screen instructions after install

# Make script exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-functions.sh"

# Check sudo and setup paths
check_sudo_and_paths

# Windows path conversion utility function
win_to_wsl_path() {
  echo "$1" | sed 's/\\/\//g; s/^\([A-Za-z]\):/\/mnt\/\L\1/'
}

# Check if wsl.exe is accessible (required for WSL operations)
echo "🔍 Verifying WSL environment..."
if ! find_wsl_exe; then
  exit 1
fi
echo "✅ WSL command access verified (using $WSL_EXE)"

# Source environment variables from .env or create if missing
set -a # automatically export all variables

if [ ! -f .env ]; then
  echo "ℹ️ No .env file found. Would you like to create one with default settings? [Y/n]"
  read -r response
  if [[ "$response" =~ ^([nN])$ ]]; then
    echo "❌ Configuration file (.env) is required but not created."
    echo "Please create it manually before running this script again."
    exit 1
  else
    echo "📝 Creating default .env file..."
    cat > .env << EOF
# WSL Alpine Build Configuration
# Generated on $(date)

# Basic Configuration
SUDO=sudo
WSL_DISTRIBUTION_NAME=alp2
CHROOT_DIR="/tmp/alp2"

# You can customize this file with additional options like:
# ALPINE_VERSION=v3.18
# EXTRA_PACKAGES="vim git curl"
# See .env.example for all available options
EOF
    echo "✅ Default .env file created"
  fi
fi

source .env
set +a

# Set default values for optional variables
ALPINE_VERSION=${ALPINE_VERSION:-edge}
EDITOR_PACKAGES=${EDITOR_PACKAGES:-"helix tree-sitter-bash tree-sitter-regex tree-sitter-json tree-sitter-toml tree-sitter-ini tree-sitter-comment"}
TOOL_PACKAGES=${TOOL_PACKAGES:-"fd bat zoxide fzf"}
EXTRA_PACKAGES=${EXTRA_PACKAGES:-""}
COMPRESSION_LEVEL=${COMPRESSION_LEVEL:-"--fast"}
SYSTEMD_ENABLED=${SYSTEMD_ENABLED:-false}
# Get real user's home directory
REAL_HOME=$(get_real_home)
WSL_INSTALL_PATH=${WSL_INSTALL_PATH:-"$REAL_HOME/alpine.wsl.gz"}

# Check for existing distribution with same name
echo "🔍 Checking for existing WSL distributions..."
if $WSL_EXE -l | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "⚠️ Warning: A WSL distribution named '$WSL_DISTRIBUTION_NAME' already exists"
  echo "This script will NOT automatically remove it."
  echo "To proceed, manually unregister it first with:"
  echo "  $WSL_EXE --unregister $WSL_DISTRIBUTION_NAME"
  exit 1
fi
echo "✅ No conflicts found with distribution name '$WSL_DISTRIBUTION_NAME'"

# Download and verify Alpine chroot install script
echo "🔍 Verifying Alpine chroot install script..."
if ! echo 'ccbf65f85cdc351851f8ad025bb3e65bae4d5b06 alpine-chroot-install' | sha1sum -c 2>/dev/null; then
  if [ -f alpine-chroot-install ]; then
    echo "⚠️ Removing existing invalid alpine-chroot-install script"
    rm alpine-chroot-install
  fi
fi

if [[ ! -f alpine-chroot-install ]]; then 
  echo "📥 Downloading alpine-chroot-install script..."
  wget https://raw.githubusercontent.com/alpinelinux/alpine-chroot-install/v0.14.0/alpine-chroot-install \
  && echo 'ccbf65f85cdc351851f8ad025bb3e65bae4d5b06 alpine-chroot-install' | sha1sum -c \
  || { echo "❌ Failed to download or verify alpine-chroot-install"; exit 1; }
  chmod +x alpine-chroot-install
fi
echo "✅ Alpine chroot install script verified"

# Create Alpine chroot environment
echo "🏗️ Building Alpine chroot environment (this may take a few minutes)..."
echo "Using Alpine version: $ALPINE_VERSION"

# Prepare package arguments
PACKAGES="openrc $EDITOR_PACKAGES $TOOL_PACKAGES $EXTRA_PACKAGES"
PACKAGE_ARGS=""
for pkg in $PACKAGES; do
  PACKAGE_ARGS="$PACKAGE_ARGS -p $pkg"
done

# Run alpine-chroot-install with all arguments
$SUDO ./alpine-chroot-install -d $CHROOT_DIR -b $ALPINE_VERSION $PACKAGE_ARGS

echo "✅ Alpine chroot environment created successfully"

# unbind the various mounts for chroot: we don't want them for wsl
echo "🔄 Cleaning up chroot mounts..."
$CHROOT_DIR/destroy
echo "✅ Chroot mounts cleaned up"

# Create WSL-specific directories and configuration files
echo "⚙️ Configuring WSL-specific settings..."
$SUDO mkdir -p $CHROOT_DIR/usr/lib/wsl
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/usr/lib/wsl/terminal-profile.json
{
  "profiles": [
    {
      "colorScheme": "Gruvbox Dark (Hard)"
    }
  ]
}
EOF

# Note: wsl-distribution.conf is not used by WSL, oobe is configured in wsl.conf above

cat << EOF | $SUDO tee -a > /dev/null $CHROOT_DIR/etc/apk/repositories
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

# Create first-boot setup script
echo "📝 Creating first-boot setup script..."
# This runs on inital start to update apk and install the other tools, this keeps
# the initial image small but with the basic usability tools.
# Assumed to run as root
cat << 'EOF' | $SUDO tee > /dev/null $CHROOT_DIR/etc/oobe.sh
#!/bin/ash
# /etc/oobe.sh - Alpine Linux first-boot setup script

# Ensure this script only runs once
if [ -f /etc/oobe.done ]; then
    exit 0
fi

echo "🚀 Running Alpine Linux first-boot setup..."

# Update and install additional packages
echo "📦 Installing additional packages..."
apk update && apk upgrade
apk add tree-sitter-markdown@testing \
    docker \
    lazydocker \
    tree-sitter-css \
    tree-sitter-html \
    tree-sitter-javascript \
    tree-sitter-typescript \
    tree-sitter-python \
    tree-sitter-rust \
    tree-sitter-c

# Enable Docker service
echo "🐳 Enabling Docker service..."
ln -sf /etc/init.d/docker /etc/runlevels/boot/docker

# Configure Helix editor
echo "📝 Configuring Helix editor..."
mkdir -p /root/.config/helix
cat << HELIX_EOF > /root/.config/helix/config.toml
theme = "gruvbox_dark_hard"
HELIX_EOF

# Clean up chroot artifacts
echo "🧹 Cleaning up installation artifacts..."
rm -f /enter-chroot /destroy /env.sh 2>/dev/null || true

# Mark setup as complete
touch /etc/oobe.done

# Remove this script
rm -f /etc/oobe.sh

echo "✅ First-boot setup complete!"
echo "====================================================="
echo "Alpine Linux is ready to use. Enjoy!"
echo "====================================================="
EOF
$SUDO chmod +x $CHROOT_DIR/etc/oobe.sh
echo "✅ First-boot setup script created"

# Configure network for Docker
echo "🔌 Setting up network configuration..."
# seems to be required for docker
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/network/interfaces
# /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback
EOF

# Configure WSL boot settings
echo "⚙️ Setting up WSL boot configuration..."
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/wsl.conf
# /etc/wsl.conf

[boot]
systemd=$SYSTEMD_ENABLED # if true, wsl will run systemd on boot
command = /sbin/openrc boot
EOF

# Configure shell environment
echo "🖥️ Configuring shell environment..."
cat << 'EOF' | $SUDO tee > /dev/null $CHROOT_DIR/root/.profile
export COLORTERM=truecolor
eval "$(zoxide init posix --hook prompt)"

# Run first-boot setup if needed
if [ -f /etc/oobe.sh ] && [ ! -f /etc/oobe.done ]; then
    /etc/oobe.sh
fi
EOF

# Package the distribution
echo "📦 Packaging WSL distribution..."
cd $CHROOT_DIR
# Use configurable compression level
$SUDO tar --numeric-owner --absolute-names -c * | gzip $COMPRESSION_LEVEL > "$WSL_INSTALL_PATH"
echo "✅ WSL distribution packaged successfully at $WSL_INSTALL_PATH"

# Install the distribution
echo "🚀 Installing WSL distribution as $WSL_DISTRIBUTION_NAME..."
import_wsl_distribution "$WSL_DISTRIBUTION_NAME" "$WSL_INSTALL_PATH"
echo "✅ WSL distribution installed successfully"

# Note: The oobe script will run automatically on first interactive login
# due to the check in /root/.profile

# Test the installation
echo "🧪 Testing WSL distribution..."
if $WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e echo "Alpine WSL test successful"; then
  echo "✅ WSL distribution verified working"
else
  echo "⚠️ Warning: WSL distribution test failed"
  echo "You may need to manually initialize the distribution."
fi

# Display completion message
cat << EOF

✅ Alpine WSL distribution installation complete!

To start using it:
  - Run: wsl -d $WSL_DISTRIBUTION_NAME
  - First boot will automatically run setup and install additional packages
  - The setup script will show progress and complete automatically
  - After first boot, restart with: wsl -t $WSL_DISTRIBUTION_NAME && wsl -d $WSL_DISTRIBUTION_NAME

To customize:
  - Edit ~/.config/helix/config.toml for Helix editor settings
  - Default user is root, consider creating a regular user account
EOF