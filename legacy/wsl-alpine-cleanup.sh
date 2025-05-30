#!/usr/bin/env bash
# WSL Alpine Comprehensive Cleanup Script
#
# This script performs a thorough cleanup of Alpine WSL installations,
# checking for all possible remnants and providing detailed guidance
#
# Usage: ./wsl-alpine-cleanup.sh [distribution-name]

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

# Accept distribution name as argument or use default
if [ $# -eq 1 ]; then
  WSL_DISTRIBUTION_NAME="$1"
else
  # Try to load from .env
  if [ -f .env ]; then
    set -a
    source .env
    set +a
  else
    WSL_DISTRIBUTION_NAME="alp2"
  fi
fi

echo "🧹 WSL Alpine Comprehensive Cleanup Tool"
echo "========================================"
echo "Target distribution: $WSL_DISTRIBUTION_NAME"
echo

# Step 1: Check current WSL status
echo "📊 Current WSL Status:"
echo "---------------------"
$WSL_EXE -l -v || echo "Failed to list distributions"
echo

# Step 2: Check if distribution is running
echo "🔍 Checking distribution status..."
if $WSL_EXE -l --running 2>/dev/null | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "⚠️  Distribution is currently running"
  echo "   Attempting to terminate..."
  $WSL_EXE -t "$WSL_DISTRIBUTION_NAME"
  sleep 2
fi

# Step 3: Scan for all related files and directories
echo "🔍 Scanning for Alpine-related files..."
echo

FOUND_ITEMS=false

# Check for distribution in WSL
if $WSL_EXE -l 2>/dev/null | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "✓ Found WSL distribution: $WSL_DISTRIBUTION_NAME"
  FOUND_ITEMS=true
fi

# Check for common file locations
FILES_TO_CHECK=(
  "$HOME/alpine.wsl.gz"
  "$HOME/alpine-test.wsl.gz"
  "./alpine-chroot-install"
  "/tmp/$WSL_DISTRIBUTION_NAME"
  "/tmp/alp2"
  "/tmp/alp-test-*"
)

DIRS_TO_CHECK=()
FILES_FOUND=()

for item in "${FILES_TO_CHECK[@]}"; do
  # Handle glob patterns
  if [[ "$item" == *"*"* ]]; then
    for expanded in $item; do
      if [ -e "$expanded" ]; then
        if [ -d "$expanded" ]; then
          DIRS_TO_CHECK+=("$expanded")
        else
          FILES_FOUND+=("$expanded")
        fi
        FOUND_ITEMS=true
      fi
    done
  else
    if [ -e "$item" ]; then
      if [ -d "$item" ]; then
        DIRS_TO_CHECK+=("$item")
      else
        FILES_FOUND+=("$item")
      fi
      FOUND_ITEMS=true
    fi
  fi
done

# Display findings
if [ ${#FILES_FOUND[@]} -gt 0 ]; then
  echo "📄 Files found:"
  for file in "${FILES_FOUND[@]}"; do
    echo "   - $file ($(du -h "$file" 2>/dev/null | cut -f1))"
  done
  echo
fi

if [ ${#DIRS_TO_CHECK[@]} -gt 0 ]; then
  echo "📁 Directories found:"
  for dir in "${DIRS_TO_CHECK[@]}"; do
    echo "   - $dir ($(du -sh "$dir" 2>/dev/null | cut -f1 || echo "size unknown"))"
  done
  echo
fi

if [ "$FOUND_ITEMS" = false ]; then
  echo "✅ No Alpine WSL remnants found. System is clean!"
  exit 0
fi

# Step 4: Ask for confirmation
echo "⚠️  WARNING: This will remove all items listed above!"
echo "Do you want to proceed with cleanup? [y/N]"
read -r response
if [[ ! "$response" =~ ^[yY] ]]; then
  echo "❌ Cleanup cancelled"
  exit 0
fi

# Step 5: Perform cleanup
echo
echo "🧹 Starting cleanup..."
echo

# Unregister WSL distribution
if $WSL_EXE -l 2>/dev/null | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "🗑️  Unregistering WSL distribution: $WSL_DISTRIBUTION_NAME"
  if $WSL_EXE --unregister "$WSL_DISTRIBUTION_NAME"; then
    echo "✅ Distribution unregistered"
  else
    echo "❌ Failed to unregister distribution"
    echo "   You may need to run this in an elevated Windows Terminal"
  fi
fi

# Remove files
for file in "${FILES_FOUND[@]}"; do
  echo "🗑️  Removing file: $file"
  if rm -f "$file" 2>/dev/null; then
    echo "✅ Removed"
  else
    echo "❌ Failed to remove (may need sudo)"
  fi
done

# Remove directories
for dir in "${DIRS_TO_CHECK[@]}"; do
  echo "🗑️  Removing directory: $dir"
  
  # Check for destroy script
  if [ -x "$dir/destroy" ]; then
    echo "   Using destroy script..."
    if "$dir/destroy" --remove 2>/dev/null; then
      echo "✅ Removed via destroy script"
      continue
    fi
  fi
  
  # Try with sudo if needed
  if [ -d "$dir" ]; then
    if sudo rm -rf "$dir" 2>/dev/null; then
      echo "✅ Removed"
    else
      echo "❌ Failed to remove"
    fi
  fi
done

# Step 6: Verify cleanup
echo
echo "🔍 Verifying cleanup..."

CLEANUP_SUCCESS=true

# Check WSL again
if $WSL_EXE -l 2>/dev/null | grep -q "$WSL_DISTRIBUTION_NAME"; then
  echo "⚠️  Distribution still exists in WSL"
  CLEANUP_SUCCESS=false
fi

# Check files again
for item in "${FILES_TO_CHECK[@]}"; do
  if [ -e "$item" ]; then
    echo "⚠️  Still exists: $item"
    CLEANUP_SUCCESS=false
  fi
done

if [ "$CLEANUP_SUCCESS" = true ]; then
  echo "✅ Cleanup completed successfully!"
else
  echo
  echo "⚠️  Some items could not be removed automatically."
  echo
  echo "📝 Manual cleanup steps:"
  echo "1. Open Windows Terminal as Administrator"
  echo "2. Run: wsl.exe --unregister $WSL_DISTRIBUTION_NAME"
  echo "3. In WSL, run: sudo rm -rf /tmp/$WSL_DISTRIBUTION_NAME"
  echo "4. Check and remove any remaining files listed above"
fi

echo
echo "💡 Additional cleanup tips:"
echo "- To remove ALL test distributions: ./wsl-alpine-build-test-cleanup.sh"
echo "- To check Windows filesystem: explorer.exe %LOCALAPPDATA%\\Packages"
echo "- WSL stores data in: %LOCALAPPDATA%\\Packages\\CanonicalGroupLimited.*"