#!/usr/bin/env bash
# Reset/Remove Alpine WSL distribution
#
# This script safely removes a WSL Alpine distribution and cleans up associated files
# It provides confirmation prompts and verification to prevent accidental deletion

# Make script exit on error
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-functions.sh"

# Check sudo and setup paths
check_sudo_and_paths

# Source environment variables from .env
set -a # automatically export all variables
if [ -f .env ]; then
  source .env
else
  echo "⚠️ Warning: No .env file found. Assuming defaults:"
  echo "  WSL_DISTRIBUTION_NAME=alp2"
  echo "  CHROOT_DIR=/tmp/alp2"
  WSL_DISTRIBUTION_NAME=${WSL_DISTRIBUTION_NAME:-alp2}
  CHROOT_DIR=${CHROOT_DIR:-"/tmp/$WSL_DISTRIBUTION_NAME"}
  echo
fi
set +a

# Verify WSL access
echo "🔍 Verifying WSL environment..."
if ! find_wsl_exe; then
  exit 1
fi

# Get the real user's home directory
REAL_HOME=$(get_real_home)

# Display warning and get confirmation
echo "⚠️ WARNING: This will completely remove the Alpine WSL distribution: $WSL_DISTRIBUTION_NAME"
echo "The following actions will be performed:"
echo "  1. Unregister the WSL distribution '$WSL_DISTRIBUTION_NAME'"
echo "  2. Remove the alpine-chroot-install script if present"
echo "  3. Delete ~/alpine.wsl.gz file if present"
echo "  4. Clean up the chroot directory: $CHROOT_DIR"
echo "  5. Remove WSL installation directory (if accessible)"
echo
echo "Continue? [y/N]"
read -r response
if [[ ! "$response" =~ ^[yY] ]]; then
  echo "Operation cancelled"
  exit 0
fi

# Check and unregister distribution
echo "🔍 Checking for WSL distribution: $WSL_DISTRIBUTION_NAME"
if $WSL_EXE -l | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "🗑️ Unregistering WSL distribution: $WSL_DISTRIBUTION_NAME"
  if ! $WSL_EXE --unregister "$WSL_DISTRIBUTION_NAME"; then
    echo "❌ Failed to unregister WSL distribution"
    echo "This may require administrator privileges in Windows"
    exit 1
  fi
  echo "✅ WSL distribution unregistered successfully"
else
  echo "ℹ️ WSL distribution '$WSL_DISTRIBUTION_NAME' not found, skipping unregister"
fi

# Clean up files
for file in ./alpine-chroot-install ~/alpine.wsl.gz; do
  if [ -f "$file" ]; then
    echo "🗑️ Removing $file"
    rm "$file" || echo "⚠️ Warning: Failed to remove $file"
  fi
done

# Clean up chroot directory
if [ -d "$CHROOT_DIR" ]; then
  echo "🗑️ Cleaning up chroot directory: $CHROOT_DIR"
  
  # Check if destroy script exists
  if [ -x "$CHROOT_DIR/destroy" ]; then
    echo "Running chroot cleanup script..."
    if ! "$CHROOT_DIR/destroy" -r; then
      echo "⚠️ Warning: Chroot cleanup script failed"
      echo "Attempting manual removal..."
      $SUDO rm -rf "$CHROOT_DIR" || echo "⚠️ Warning: Failed to remove chroot directory"
    fi
  else
    echo "No chroot cleanup script found, attempting direct removal..."
    $SUDO rm -rf "$CHROOT_DIR" || echo "⚠️ Warning: Failed to remove chroot directory"
  fi
  
  # Verify removal
  if [ ! -d "$CHROOT_DIR" ]; then
    echo "✅ Chroot directory removed successfully"
  else
    echo "⚠️ Warning: Chroot directory may still exist at $CHROOT_DIR"
  fi
else
  echo "ℹ️ Chroot directory not found at $CHROOT_DIR, skipping cleanup"
fi

# Clean up WSL installation directories
cleanup_wsl_dirs "$WSL_DISTRIBUTION_NAME"

echo "🧹 Cleanup complete!"
echo "✅ Alpine WSL distribution and associated files have been removed"