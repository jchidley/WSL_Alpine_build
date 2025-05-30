#!/usr/bin/env bash
set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-functions.sh"

# Check sudo and setup paths
check_sudo_and_paths

# Find wsl.exe
if ! find_wsl_exe; then
  exit 1
fi

# Default pattern for test distributions created by test-wsl-alpine-build.sh
TEST_PATTERN="$TEST_DISTRIBUTION_PATTERN"

# Process command line arguments
REMOVE_DIRS=true
ALL_DISTRIBUTIONS=false

print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Clean up test WSL distributions created by test-wsl-alpine-build.sh"
  echo
  echo "Options:"
  echo "  -h, --help              Show this help message"
  echo "  -a, --all               Show all distributions (not just test ones)"
  echo "  -n, --no-remove-dirs    Don't remove installation directories"
  echo "  -p, --pattern PATTERN   Custom regex pattern for identifying test distributions"
  echo
  echo "By default, this script only removes distributions with names matching:"
  echo "  $TEST_PATTERN"
  echo "These are the test distributions created by test-wsl-alpine-build.sh"
  echo
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_usage
      exit 0
      ;;
    -a|--all)
      ALL_DISTRIBUTIONS=true
      shift
      ;;
    -n|--no-remove-dirs)
      REMOVE_DIRS=false
      shift
      ;;
    -p|--pattern)
      if [[ -z "$2" || "$2" == -* ]]; then
        log_error "--pattern requires an argument"
        exit 1
      fi
      TEST_PATTERN="$2"
      shift 2
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# We don't need to load environment variables from .env
# Test distributions use a standard location at /tmp/distribution-name

# Get list of WSL distributions
log_info "Scanning for WSL distributions..."
WSL_LIST=$(get_wsl_distributions)

# Filter distributions based on pattern
if [[ "$ALL_DISTRIBUTIONS" = true ]]; then
  log_info "Showing all WSL distributions:"
  echo "$WSL_LIST"
else
  log_info "Showing test WSL distributions (matching pattern: $TEST_PATTERN):"
  MATCHING=$(echo "$WSL_LIST" | grep -E "$TEST_PATTERN" || echo "")
  if [[ -z "$MATCHING" ]]; then
    log_info "No matching distributions found."
    exit 0
  else
    echo "$MATCHING"
  fi
fi

# Extract and process distributions
echo
log_progress "Cleaning up distributions..."

if [[ "$ALL_DISTRIBUTIONS" = true ]]; then
  # Process all distributions (but still only focus on test distributions)
  # This is a way to show all WSL distributions but only act on test ones
  log_warning "Note: Even with --all option, only test distributions ($TEST_DISTRIBUTION_PREFIX*) will be removed"
  
  while IFS= read -r DISTRO; do
    # Skip empty lines and header
    if [[ -z "$DISTRO" || "$DISTRO" == "NAME" ]]; then
      continue
    fi
    
    # Only remove test distributions
    if ! [[ "$DISTRO" =~ $TEST_PATTERN ]]; then
      log_info "Skipping non-test distribution: $DISTRO"
      continue
    fi
    
    # Unregister the distribution
    unregister_distribution "$DISTRO"
    
    if [[ "$REMOVE_DIRS" = true ]]; then
      # For test distributions, use the default /tmp/distribution-name pattern
      CHROOT_DIR="/tmp/$DISTRO"
      
      # Clean up chroot directory
      cleanup_chroot_dir "$CHROOT_DIR"
      
      # Also remove WSL installation directory
      cleanup_wsl_dirs "$DISTRO"
    fi
  done <<< "$WSL_LIST"
else
  # Process only matching distributions
  while IFS= read -r DISTRO; do
    # Skip empty lines
    if [[ -z "$DISTRO" ]]; then
      continue
    fi
    
    # Unregister the distribution
    unregister_distribution "$DISTRO"
    
    if [[ "$REMOVE_DIRS" = true ]]; then
      # For test distributions, use the default /tmp/distribution-name pattern
      CHROOT_DIR="/tmp/$DISTRO"
      
      # Clean up chroot directory
      cleanup_chroot_dir "$CHROOT_DIR"
      
      # Also remove WSL installation directory
      cleanup_wsl_dirs "$DISTRO"
    fi
  done <<< "$MATCHING"
fi

# Clean up other files
log_progress "Removing temporary files..."
safe_remove_file ~/alpine.wsl.gz "WSL distribution archive"

log_success "Cleanup completed!"