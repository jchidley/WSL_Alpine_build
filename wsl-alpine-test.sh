#!/usr/bin/env bash
# WSL Alpine Build Test Script
#
# This script tests the wsl-alpine-build.sh script with a uniquely named test distribution
# It creates a temporary test environment, verifies the build, and optionally cleans up
#
# ⚠️ For testing purposes only - uses a uniquely named distribution to avoid conflicts

# Make script exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-functions.sh"

# Check sudo and setup paths
check_sudo_and_paths

# Generate unique test name with timestamp
TEST_TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEST_NAME="alp-test-${TEST_TIMESTAMP}"

# Check if wsl.exe is accessible (required for WSL operations)
echo "🔍 Verifying WSL environment..."
if ! find_wsl_exe; then
  exit 1
fi
echo "✅ WSL command access verified (using $WSL_EXE)"

# Save original .env if it exists
if [ -f .env ]; then
  cp .env .env.test-backup
  HAD_ENV=true
else
  HAD_ENV=false
fi

# Get real home directory
REAL_HOME=$(get_real_home)

# Create test configuration
echo "📝 Creating test environment configuration..."
cat > .env << EOF
# Test configuration created by $(basename "$0")
# Generated on $(date)

# Basic Configuration
SUDO=$SUDO
WSL_DISTRIBUTION_NAME=$TEST_NAME
CHROOT_DIR=/tmp/$TEST_NAME
WSL_INSTALL_PATH=$REAL_HOME/alpine-test.wsl.gz

# Optional Configuration (modify as needed for testing)
# ALPINE_VERSION=v3.18
# EDITOR_PACKAGES="helix tree-sitter-bash tree-sitter-regex"
# TOOL_PACKAGES="fd bat zoxide fzf"
# EXTRA_PACKAGES=""
# COMPRESSION_LEVEL=--fast
# SYSTEMD_ENABLED=false
EOF

echo "🧪 Testing WSL Alpine build with configuration:"
echo "  - Distribution name: $TEST_NAME"
echo "  - Chroot directory: /tmp/$TEST_NAME"
echo "  - Install path: $REAL_HOME/alpine-test.wsl.gz"

# Test options menu
echo
echo "Select test option:"
echo "  1. Standard test (build and verify)"
echo "  2. Quick test (verify WSL commands only)"
echo "  3. Advanced test (customize Alpine version and packages)"
echo "  4. Exit without testing"
read -p "Select option [1-4]: " -r test_option

case $test_option in
  1)
    echo "🚀 Running standard test..."
    ;;
  2)
    echo "🔍 Running quick WSL command verification only..."
    # Test WSL commands without building
    echo "Testing WSL command functionality..."
    if $WSL_EXE --version &>/dev/null; then
      echo "✅ WSL commands working correctly"
    else
      echo "❌ WSL commands failed"
    fi
    
    # Cleanup and exit
    if [ "$HAD_ENV" = true ]; then
      mv .env.test-backup .env
    else
      rm -f .env
    fi
    exit 0
    ;;
  3)
    echo "🔧 Configuring advanced test options..."
    read -p "Alpine version (e.g., v3.18, edge) [default: edge]: " alpine_version
    read -p "Extra packages (space-separated) [default: none]: " extra_packages
    
    # Update .env with custom parameters if provided
    if [ -n "$alpine_version" ]; then
      echo "ALPINE_VERSION=$alpine_version" >> .env
    fi
    if [ -n "$extra_packages" ]; then
      echo "EXTRA_PACKAGES=\"$extra_packages\"" >> .env
    fi
    echo "✅ Advanced configuration applied"
    ;;
  4|*)
    echo "Test aborted."
    # Restore original .env
    if [ "$HAD_ENV" = true ]; then
      mv .env.test-backup .env
    else
      rm -f .env
    fi
    exit 0
    ;;
esac

# Run the actual build script
echo "🚀 Running wsl-alpine-build.sh..."
if ! ./wsl-alpine-build.sh 2>&1 | tee test-output.log; then
  echo "❌ Build script failed. Check test-output.log for details"
  
  # Restore original .env
  if [ "$HAD_ENV" = true ]; then
    mv .env.test-backup .env
  else
    rm -f .env
  fi
  exit 1
fi

# Restore original .env
if [ "$HAD_ENV" = true ]; then
  mv .env.test-backup .env
  echo "✅ Restored original .env file"
else
  rm -f .env
  echo "✅ Removed temporary .env file"
fi

# Verify the distribution was created
echo "🔍 Verifying installation..."
echo "Checking WSL distributions:"
$WSL_EXE --list
echo ""

# Give WSL a moment to register the new distribution
echo "Waiting for WSL to register the new distribution..."
sleep 5

# Check if distribution exists
if ! $WSL_EXE --list | grep -q "$TEST_NAME"; then
  echo "❌ Test distribution was not found. Build may have failed."
  exit 1
fi

# Test if the distribution can run commands
echo "🧪 Testing distribution functionality..."
echo "Running command in $TEST_NAME..."

if ! $WSL_EXE -d "$TEST_NAME" -e echo "Alpine test successful"; then
  echo "❌ Distribution was created but cannot run commands."
  exit 1
fi
echo "✅ Command executed successfully!"

# Test Alpine-specific features
echo "🧪 Verifying Alpine Linux..."
ALPINE_VERSION=$($WSL_EXE -d "$TEST_NAME" -e cat /etc/alpine-release 2>&1)
echo "✅ Confirmed Alpine Linux version: $ALPINE_VERSION"

# Test installed tools
echo "🧪 Verifying installed tools..."
TOOLS=("hx" "zoxide" "bat" "fd" "fzf")
TOOL_NAMES=("Helix editor" "zoxide" "bat" "fd" "fzf")

for i in "${!TOOLS[@]}"; do
  if $WSL_EXE -d "$TEST_NAME" -e which "${TOOLS[$i]}" &>/dev/null; then
    echo "✅ ${TOOL_NAMES[$i]} installed"
  else
    echo "⚠️ Warning: ${TOOL_NAMES[$i]} not found in PATH"
  fi
done

echo "✅ WSL Alpine build test passed successfully!"
echo "Distribution $TEST_NAME is installed and working correctly."

# Ask about cleanup
echo
echo "Test cleanup options:"
echo "  1. Remove test distribution"
echo "  2. Keep test distribution for further inspection"
read -p "Select option [1-2]: " -r cleanup_option

case $cleanup_option in
  1)
    echo "🧹 Removing test distribution..."
    if $WSL_EXE --unregister "$TEST_NAME"; then
      echo "✅ Test distribution removed"
      
      # Clean up test files
      if [ -f "$REAL_HOME/alpine-test.wsl.gz" ]; then
        rm "$REAL_HOME/alpine-test.wsl.gz"
        echo "✅ Removed test archive"
      fi
      
      # Clean up WSL directories
      cleanup_wsl_dirs "$TEST_NAME"
      
      # Clean up chroot directory
      if [ -d "/tmp/$TEST_NAME" ]; then
        if [ -x "/tmp/$TEST_NAME/destroy" ]; then
          $SUDO "/tmp/$TEST_NAME/destroy" -r
        else
          $SUDO rm -rf "/tmp/$TEST_NAME"
        fi
        echo "✅ Removed chroot directory"
      fi
    else
      echo "⚠️ Failed to remove test distribution"
    fi
    ;;
  2|*)
    echo "ℹ️ Test distribution kept for further inspection"
    echo "You can access it with: wsl -d $TEST_NAME"
    echo "When done, remove it with: wsl --unregister $TEST_NAME"
    echo "Also remove: $REAL_HOME/alpine-test.wsl.gz"
    ;;
esac

echo "🏁 Test process completed"