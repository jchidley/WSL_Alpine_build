#!/bin/bash
# ABOUTME: Test harness for the minirootfs Alpine WSL build script
# ABOUTME: Runs various test scenarios to ensure the build works correctly

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print header
echo "==============================================="
echo "Alpine WSL MinirootFS Build Test Suite"
echo "==============================================="
echo ""

# Test function
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_result="${3:-0}"
    
    echo -n "Running: $test_name... "
    ((TESTS_RUN++))
    
    if output=$($test_cmd 2>&1); then
        if [ "$expected_result" -eq 0 ]; then
            echo -e "${GREEN}PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAIL${NC} (expected failure but succeeded)"
            echo "Output: $output"
            ((TESTS_FAILED++))
        fi
    else
        local exit_code=$?
        if [ "$expected_result" -ne 0 ]; then
            echo -e "${GREEN}PASS${NC} (expected failure)"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}FAIL${NC} (exit code: $exit_code)"
            echo "Output: $output"
            ((TESTS_FAILED++))
        fi
    fi
}

# Test 1: Help message
run_test "Help message" "./wsl-alpine-build-minirootfs.sh --help"

# Test 2: Self-tests
run_test "Self-tests" "./wsl-alpine-build-minirootfs.sh --test"

# Test 3: Dry run with default settings
run_test "Dry run (default)" "./wsl-alpine-build-minirootfs.sh --dry-run --no-import"

# Test 4: Dry run with custom settings
run_test "Dry run (custom)" "ALPINE_VERSION=3.19.0 DISTRO_NAME=test-alpine ./wsl-alpine-build-minirootfs.sh --dry-run --no-import"

# Test 5: Verbose dry run
run_test "Verbose dry run" "./wsl-alpine-build-minirootfs.sh --verbose --dry-run --no-import"

# Test 6: Debug dry run
run_test "Debug dry run" "./wsl-alpine-build-minirootfs.sh --debug --dry-run --no-import 2>/dev/null"

# Test 7: Invalid Alpine version
run_test "Invalid Alpine version" "ALPINE_VERSION=invalid ./wsl-alpine-build-minirootfs.sh --dry-run" 1

# Test 8: Invalid architecture
run_test "Invalid architecture" "ARCH=invalid ./wsl-alpine-build-minirootfs.sh --dry-run" 1

# Test 9: Invalid distro name
run_test "Invalid distro name" "DISTRO_NAME='123-invalid' ./wsl-alpine-build-minirootfs.sh --dry-run" 1

# Test 10: Check if script is executable
if [ -x "./wsl-alpine-build-minirootfs.sh" ]; then
    echo -e "Script permissions: ${GREEN}OK${NC} (executable)"
else
    echo -e "Script permissions: ${RED}FAIL${NC} (not executable)"
    echo "Run: chmod +x wsl-alpine-build-minirootfs.sh"
fi

# Summary
echo ""
echo "==============================================="
echo "Test Summary"
echo "==============================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi