#!/bin/bash
# Quick test of the minirootfs build script

set -euo pipefail

echo "=== Quick Test of Alpine WSL MinirootFS Build ==="
echo ""

# Test 1: Help
echo "1. Testing help..."
if ./wsl-alpine-build-minirootfs.sh --help >/dev/null 2>&1; then
    echo "   ✓ Help works"
else
    echo "   ✗ Help failed"
fi

# Test 2: Dry run
echo "2. Testing dry run..."
if DISTRO_NAME=test-alpine-dryrun ./wsl-alpine-build-minirootfs.sh --dry-run --no-import 2>&1 | grep -q "DRY RUN"; then
    echo "   ✓ Dry run works"
else
    echo "   ✗ Dry run failed"
fi

# Test 3: Check if minirootfs exists
echo "3. Checking for cached minirootfs..."
if ls alpine-minirootfs-*.tar.gz 2>/dev/null; then
    echo "   ✓ Found cached minirootfs"
else
    echo "   ℹ No cached minirootfs (will download on real run)"
fi

echo ""
echo "Basic tests complete. Ready to run actual build."