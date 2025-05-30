#!/bin/bash
# ABOUTME: Comprehensive test script for the modular Alpine WSL build
# ABOUTME: Tests build, installation, and all configured features

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DISTRO_NAME="alpine-test-$(date +%Y%m%d-%H%M%S)"
TEST_OUTPUT_FILE="test-alpine.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}Alpine WSL Modular Build Test Suite${NC}"
echo "===================================="
echo "Test distribution: $TEST_DISTRO_NAME"
echo ""

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

# Function to check if command exists in test distro
check_command() {
    local cmd=$1
    wsl.exe -d "$TEST_DISTRO_NAME" --cd / -e sh -c "command -v $cmd >/dev/null 2>&1"
}

# Function to run command in test distro
run_in_distro() {
    wsl.exe -d "$TEST_DISTRO_NAME" --cd / -e sh -c "$@"
}

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up test distribution..."
    wsl.exe --unregister "$TEST_DISTRO_NAME" 2>/dev/null || true
    rm -f "$TEST_OUTPUT_FILE"
    rm -rf alpine-wsl-build
}

# Set trap for cleanup
trap cleanup EXIT

# Step 1: Build the distribution
echo "Step 1: Building Alpine distribution..."
echo "--------------------------------------"

if "$SCRIPT_DIR/wsl-alpine-build-modular.sh" \
    --name "$TEST_DISTRO_NAME" \
    --output "$TEST_OUTPUT_FILE" \
    --verbose; then
    print_result 0 "Build completed successfully"
else
    print_result 1 "Build failed"
    exit 1
fi

# Step 2: Check build output
echo ""
echo "Step 2: Verifying build output..."
echo "---------------------------------"

if [ -f "$TEST_OUTPUT_FILE" ]; then
    size=$(du -h "$TEST_OUTPUT_FILE" | cut -f1)
    print_result 0 "Output file created: $TEST_OUTPUT_FILE ($size)"
else
    print_result 1 "Output file not found"
    exit 1
fi

# Step 3: Import is automatic, but verify it worked
echo ""
echo "Step 3: Verifying WSL import..."
echo "--------------------------------"

if wsl.exe --list --quiet | grep -q "^${TEST_DISTRO_NAME}$"; then
    print_result 0 "Distribution imported successfully"
else
    print_result 1 "Distribution not found in WSL"
    exit 1
fi

# Wait for first boot to complete
echo ""
echo "Waiting for first-boot setup to complete..."
sleep 5

# Step 4: Test installed packages
echo ""
echo "Step 4: Testing installed packages..."
echo "-------------------------------------"

# Core packages
for pkg in sudo git openrc helix fd bat zoxide fzf docker lazydocker; do
    if check_command "$pkg"; then
        print_result 0 "Package installed: $pkg"
    else
        print_result 1 "Package missing: $pkg"
    fi
done

# Step 5: Test configurations
echo ""
echo "Step 5: Testing configurations..."
echo "---------------------------------"

# Check Helix config
if run_in_distro "test -f /root/.config/helix/config.toml"; then
    theme=$(run_in_distro "grep theme /root/.config/helix/config.toml" || echo "")
    if [[ "$theme" == *"gruvbox_dark_hard"* ]]; then
        print_result 0 "Helix configured with Gruvbox theme"
    else
        print_result 1 "Helix theme not configured"
    fi
else
    print_result 1 "Helix config not found"
fi

# Check Docker service
if run_in_distro "rc-status 2>/dev/null | grep -q docker || ls -la /etc/runlevels/boot/ | grep -q docker"; then
    print_result 0 "Docker service enabled"
else
    print_result 1 "Docker service not enabled"
fi

# Check network config
if run_in_distro "test -f /etc/network/interfaces"; then
    print_result 0 "Network configuration exists"
else
    print_result 1 "Network configuration missing"
fi

# Check terminal profile
if run_in_distro "test -f /usr/lib/wsl/terminal-profile.json"; then
    print_result 0 "Terminal profile configured"
else
    print_result 1 "Terminal profile missing"
fi

# Step 6: Test shell environment
echo ""
echo "Step 6: Testing shell environment..."
echo "------------------------------------"

# Check zoxide in profile
if run_in_distro "grep -q zoxide /root/.profile"; then
    print_result 0 "Zoxide configured in shell"
else
    print_result 1 "Zoxide not configured"
fi

# Check COLORTERM
if run_in_distro "grep -q COLORTERM /root/.profile"; then
    print_result 0 "COLORTERM configured"
else
    print_result 1 "COLORTERM not configured"
fi

# Step 7: Test Claude Code installation (if requested)
echo ""
echo "Step 7: Claude Code installation test..."
echo "----------------------------------------"
read -p "Test Claude Code installation? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Copy the installer to the test distro
    wsl.exe -d "$TEST_DISTRO_NAME" --cd / -e mkdir -p /tmp/install
    cp "$SCRIPT_DIR/wsl-alpine-claude-code.sh" alpine-wsl-build/
    
    # Convert to Windows path and copy
    win_path=$(wslpath -w "alpine-wsl-build/wsl-alpine-claude-code.sh")
    wsl.exe -d "$TEST_DISTRO_NAME" --cd / -e cp "$(wslpath -u "$win_path")" /tmp/install/
    
    # Run the installer
    if run_in_distro "cd /tmp/install && ash ./wsl-alpine-claude-code.sh --native"; then
        print_result 0 "Claude Code installer ran successfully"
        
        # Check if claude command exists
        if check_command "claude"; then
            print_result 0 "Claude command available"
        else
            print_result 1 "Claude command not found"
        fi
    else
        print_result 1 "Claude Code installation failed"
    fi
else
    echo "Skipping Claude Code installation test"
fi

# Summary
echo ""
echo "Test Summary"
echo "============"
echo "Distribution '$TEST_DISTRO_NAME' is ready for manual testing."
echo ""
echo "To access the test distribution:"
echo "  wsl.exe -d $TEST_DISTRO_NAME -u root --cd /"
echo ""
echo "To test specific features:"
echo "  - Helix: hx /etc/apk/repositories"
echo "  - Docker: docker run hello-world"
echo "  - Terminal tools: fd --version, bat --version, zoxide --version"
echo "  - Claude Code: claude --version (if installed)"
echo ""
read -p "Keep test distribution for manual testing? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    trap - EXIT
    echo "Test distribution kept. To remove later:"
    echo "  wsl.exe --unregister $TEST_DISTRO_NAME"
else
    echo "Cleaning up..."
fi