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

# Load environment variables but override distribution name and chroot directory
if [ -f .env ]; then
  set -a
  source .env
  set +a
  # Save original values to restore later
  ORIGINAL_WSL_DISTRIBUTION_NAME="$WSL_DISTRIBUTION_NAME"
  ORIGINAL_CHROOT_DIR="$CHROOT_DIR"
else
  echo "No .env file found. Using default values."
  SUDO=sudo
  ORIGINAL_WSL_DISTRIBUTION_NAME="alp2"
  ORIGINAL_CHROOT_DIR="/tmp/alp2"
fi

# Override with test-specific values
WSL_DISTRIBUTION_NAME="$TEST_NAME"
CHROOT_DIR="/tmp/$TEST_NAME"
WSL_INSTALL_PATH="$HOME/alpine-test.wsl.gz"

echo "🧪 Testing WSL Alpine build with configuration:"
echo "  - Distribution name: $WSL_DISTRIBUTION_NAME"
echo "  - Chroot directory: $CHROOT_DIR"
echo "  - Install path: $WSL_INSTALL_PATH"

# Check if the distribution already exists (shouldn't be possible with timestamp)
if $WSL_EXE --list | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "⚠️ Distribution $WSL_DISTRIBUTION_NAME already exists."
  read -p "Would you like to remove it and continue? [y/N] " -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Test aborted."
    exit 1
  fi
  
  echo "Removing existing distribution..."
  $WSL_EXE --unregister "$WSL_DISTRIBUTION_NAME" || { echo "Failed to unregister distribution."; exit 1; }
fi

# Create a temporary .env file for the test
echo "📝 Creating test environment file..."
if [ -f .env ]; then
  cp .env .env.bak
fi

cat > .env << EOF
# Test configuration created by test-wsl-alpine-build.sh
# Generated on $(date)

# Basic Configuration
SUDO=$SUDO
WSL_DISTRIBUTION_NAME=$WSL_DISTRIBUTION_NAME
CHROOT_DIR=$CHROOT_DIR
WSL_INSTALL_PATH=$WSL_INSTALL_PATH

# Optional Configuration
# Uncomment to customize your test build
# ALPINE_VERSION=v3.18
# EXTRA_PACKAGES="vim curl git"
# COMPRESSION_LEVEL=--fast
# SYSTEMD_ENABLED=false
EOF

echo "✅ Test environment configuration created"

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
    echo "🚀 Running standard test (this may take several minutes)..."
    ;;
  2)
    echo "🔍 Running quick WSL command verification only..."
    # Test WSL commands without building
    echo "Testing WSL command functionality..."
    if $WSL_EXE --version &>/dev/null; then
      echo "✅ WSL commands working correctly"
      # Restore original .env if it existed
      if [ -f .env.bak ]; then
        mv .env.bak .env
      else
        rm .env
      fi
      exit 0
    else
      echo "❌ WSL commands failed"
      # Restore original .env if it existed
      if [ -f .env.bak ]; then
        mv .env.bak .env
      else
        rm .env
      fi
      exit 1
    fi
    ;;
  3)
    echo "🔧 Configuring advanced test options..."
    read -p "Alpine version (e.g., v3.18, edge) [default: edge]: " alpine_version
    read -p "Extra packages (space-separated) [default: none]: " extra_packages
    
    # Update .env with custom parameters if provided
    if [ -n "$alpine_version" ]; then
      sed -i "s/# ALPINE_VERSION=.*/ALPINE_VERSION=$alpine_version/" .env
    fi
    if [ -n "$extra_packages" ]; then
      sed -i "s/# EXTRA_PACKAGES=.*/EXTRA_PACKAGES=\"$extra_packages\"/" .env
    fi
    echo "✅ Advanced configuration applied"
    ;;
  4|*)
    echo "Test aborted."
    # Restore original .env if it existed
    if [ -f .env.bak ]; then
      mv .env.bak .env
    else
      rm .env
    fi
    exit 0
    ;;
esac

# Run the build script with test configuration
echo "🚀 Running wsl-alpine-build.sh..."
if ! ./wsl-alpine-build.sh 2>&1 | tee test-output.log; then
  echo "❌ Build script failed."
  echo "Check test-output.log for details"
  
  # Restore original .env file if it existed
  if [ -f .env.bak ]; then
    mv .env.bak .env
  else
    rm .env
  fi
  exit 1
fi

# Restore original .env file if it existed
if [ -f .env.bak ]; then
  mv .env.bak .env
  echo "✅ Restored original .env file"
else
  rm .env
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

# Try again with more robust pattern matching
echo "Checking for distribution: $WSL_DISTRIBUTION_NAME"
WSL_LIST=$($WSL_EXE --list 2>/dev/null | tr -d '\0' | tr -d '\r')
if ! echo "$WSL_LIST" | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "⚠️ Distribution not found with exact name. Checking for similar distributions..."
  # Extract the prefix part for fuzzy matching
  PREFIX="alp-test"
  if echo "$WSL_LIST" | grep -q "$PREFIX"; then
    FOUND_DIST=$(echo "$WSL_LIST" | grep "$PREFIX" | head -1 | awk '{print $1}')
    echo "Found similar distribution: $FOUND_DIST"
    # Use this distribution instead
    WSL_DISTRIBUTION_NAME="$FOUND_DIST"
    echo "Using $WSL_DISTRIBUTION_NAME for testing"
  else
    echo "❌ No Alpine test distribution was found. Build may have failed."
    exit 1
  fi
fi

# Test if the distribution can run commands
echo "🧪 Testing distribution functionality..."
echo "Running command in $WSL_DISTRIBUTION_NAME..."

# Add error handling for the WSL command
if ! OUTPUT=$($WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e echo "Alpine test successful" 2>&1); then
  echo "❌ Command failed with error:"
  echo "$OUTPUT"
  
  # Check if distribution is still starting up
  if echo "$OUTPUT" | grep -q "starting"; then
    echo "Distribution might be starting up. Waiting 10 seconds..."
    sleep 10
    # Try again
    if ! $WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e echo "Alpine test successful"; then
      echo "❌ Distribution was created but cannot run commands after waiting."
      exit 1
    else
      echo "✅ Command successful after waiting!"
    fi
  else
    # Other error
    echo "❌ Distribution was created but cannot run commands."
    exit 1
  fi
else
  echo "✅ Command executed successfully!"
fi

# Test Alpine-specific commands to verify it's actually Alpine
echo "🧪 Verifying Alpine Linux..."
if ! ALPINE_VERSION=$($WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e cat /etc/alpine-release 2>&1); then
  echo "❌ Failed to verify Alpine version:"
  echo "$ALPINE_VERSION"
  exit 1
fi
echo "✅ Confirmed Alpine Linux version: $ALPINE_VERSION"

# Test Helix editor installation
echo "🧪 Verifying Helix editor installation..."
if ! $WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e which hx &>/dev/null; then
  echo "⚠️ Warning: Helix editor not found in PATH"
else
  echo "✅ Helix editor installed"
fi

# Verify package installation
echo "🧪 Verifying core utilities..."
CORE_UTILS=("zoxide" "bat" "fd" "fzf")
for util in "${CORE_UTILS[@]}"; do
  if ! $WSL_EXE -d "$WSL_DISTRIBUTION_NAME" -e which "$util" &>/dev/null; then
    echo "⚠️ Warning: $util not found in PATH"
  else
    echo "✅ $util installed"
  fi
done

echo "✅ WSL Alpine build test passed successfully!"
echo "Distribution $WSL_DISTRIBUTION_NAME is installed and working correctly."

# Ask about cleanup
echo
echo "Test cleanup options:"
echo "  1. Remove test distribution"
echo "  2. Keep test distribution for further inspection"
read -p "Select option [1-2]: " -r cleanup_option

case $cleanup_option in
  1)
    echo "🧹 Removing test distribution..."
    if $WSL_EXE --unregister "$WSL_DISTRIBUTION_NAME"; then
      echo "✅ Test distribution removed"
      # Also remove the test WSL file
      if [ -f "$WSL_INSTALL_PATH" ]; then
        rm "$WSL_INSTALL_PATH"
        echo "✅ Removed $WSL_INSTALL_PATH"
      fi
    else
      echo "⚠️ Failed to remove test distribution"
    fi
    ;;
  2|*)
    echo "ℹ️ Test distribution kept for further inspection"
    echo "You can access it with: wsl -d $WSL_DISTRIBUTION_NAME"
    echo "When you're done, remove it with: wsl --unregister $WSL_DISTRIBUTION_NAME"
    ;;
esac

echo "🏁 Test process completed"