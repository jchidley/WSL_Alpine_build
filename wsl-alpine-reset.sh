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

# Load configuration
if ! load_config .env; then
  log_info "Using default configuration:"
  log_info "  WSL_DISTRIBUTION_NAME=$DEFAULT_DISTRIBUTION_NAME"
  log_info "  CHROOT_DIR=/tmp/$DEFAULT_DISTRIBUTION_NAME"
  WSL_DISTRIBUTION_NAME=$DEFAULT_DISTRIBUTION_NAME
  CHROOT_DIR="/tmp/$WSL_DISTRIBUTION_NAME"
  echo
fi

# Verify WSL access
log_progress "Verifying WSL environment..."
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
log_progress "Checking for WSL distribution: $WSL_DISTRIBUTION_NAME"
if distribution_exists "$WSL_DISTRIBUTION_NAME"; then
  unregister_distribution "$WSL_DISTRIBUTION_NAME"
else
  log_info "WSL distribution '$WSL_DISTRIBUTION_NAME' not found, skipping unregister"
fi

# Clean up files
safe_remove_file "./alpine-chroot-install" "Alpine chroot install script"
safe_remove_file "$REAL_HOME/alpine.wsl.gz" "WSL distribution archive"

# Clean up chroot directory
cleanup_chroot_dir "$CHROOT_DIR"

# Clean up WSL installation directories
cleanup_wsl_dirs "$WSL_DISTRIBUTION_NAME"

log_progress "Cleanup complete!"
log_success "Alpine WSL distribution and associated files have been removed"