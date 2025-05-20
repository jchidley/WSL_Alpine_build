#!/usr/bin/env bash
set -e

# Default pattern for test distributions created by test-wsl-alpine-build.sh
TEST_PATTERN="alp-test-[0-9]+"

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
        echo "Error: --pattern requires an argument"
        exit 1
      fi
      TEST_PATTERN="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# We don't need to load environment variables from .env
# Test distributions use a standard location at /tmp/distribution-name

# Get list of WSL distributions
echo "Scanning for WSL distributions..."
WSL_LIST=$(wsl.exe --list --verbose 2>/dev/null | tr -d '\0\r')

# Filter distributions based on pattern or show all
if [[ "$ALL_DISTRIBUTIONS" = true ]]; then
  echo "Showing all WSL distributions:"
  echo "$WSL_LIST"
else
  echo "Showing test WSL distributions (matching pattern: $TEST_PATTERN):"
  MATCHING=$(echo "$WSL_LIST" | grep -E "$TEST_PATTERN" || echo "")
  if [[ -z "$MATCHING" ]]; then
    echo "No matching distributions found."
    exit 0
  else
    echo "$MATCHING"
  fi
fi

# Extract and process distributions
echo
echo "Cleaning up distributions..."

if [[ "$ALL_DISTRIBUTIONS" = true ]]; then
  # Process all distributions (but still only focus on test distributions)
  # This is a way to show all WSL distributions but only act on test ones
  echo "Note: Even with --all option, only test distributions (alp-test-*) will be removed"
  tail -n +2 <<< "$WSL_LIST" | while IFS= read -r line; do
    if [[ "$line" =~ [[:space:]]*([^[:space:]]+) ]]; then
      DISTRO="${BASH_REMATCH[1]}"
      # Skip Windows entries
      if [[ "$DISTRO" != "Windows" && -n "$DISTRO" ]]; then
        # Only remove test distributions
        if ! [[ "$DISTRO" =~ alp-test- ]]; then
          echo "Skipping non-test distribution: $DISTRO"
          continue
        fi
        
        echo "Unregistering test distribution: $DISTRO..."
        wsl.exe --unregister "$DISTRO"
        
        if [[ "$REMOVE_DIRS" = true ]]; then
          # For distributions, use the default /tmp/distribution-name pattern
          CHROOT_DIR="/tmp/$DISTRO"
          
          echo "Removing chroot directory: $CHROOT_DIR"
          if [ -d "$CHROOT_DIR" ]; then
            if [ -x "$CHROOT_DIR/destroy" ]; then
              sudo "$CHROOT_DIR/destroy" -r
            else
              sudo rm -rf "$CHROOT_DIR"
            fi
          fi
        fi
      fi
    fi
  done
else
  # Process only matching distributions
  grep -E "$TEST_PATTERN" <<< "$WSL_LIST" | while IFS= read -r line; do
    if [[ "$line" =~ [[:space:]]*([^[:space:]]+) ]]; then
      DISTRO="${BASH_REMATCH[1]}"
      # Skip header lines and the main distribution
      if [[ "$DISTRO" != "NAME" && "$DISTRO" != "Windows" && -n "$DISTRO" ]]; then
        # Skip any non-test distributions when not in "all" mode
        if ! [[ "$DISTRO" =~ alp-test- ]]; then
          echo "Skipping non-test distribution: $DISTRO"
          continue
        fi
        
        echo "Unregistering test distribution: $DISTRO..."
        wsl.exe --unregister "$DISTRO"
        
        if [[ "$REMOVE_DIRS" = true ]]; then
          # For test distributions, use the default /tmp/distribution-name pattern
          CHROOT_DIR="/tmp/$DISTRO"
          
          echo "Removing chroot directory: $CHROOT_DIR"
          if [ -d "$CHROOT_DIR" ]; then
            if [ -x "$CHROOT_DIR/destroy" ]; then
              sudo "$CHROOT_DIR/destroy" -r
            else
              sudo rm -rf "$CHROOT_DIR"
            fi
          fi
        fi
      fi
    fi
  done
fi

# Clean up other files
echo "Removing temporary files..."
if [ -f ~/alpine.wsl.gz ]; then
  rm ~/alpine.wsl.gz
  echo "Removed ~/alpine.wsl.gz"
fi

echo "Cleanup completed!"