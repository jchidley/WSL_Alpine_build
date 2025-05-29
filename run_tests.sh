#!/bin/bash
# ABOUTME: Simple test runner for Alpine WSL build
# ABOUTME: Runs tests without requiring external test frameworks

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test runner
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -n "  $test_name ... "
    ((TESTS_RUN++))
    
    if output=$($test_function 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "    Output: $output"
        ((TESTS_FAILED++))
    fi
}

echo "==================================="
echo "Alpine WSL Build Test Suite"
echo "==================================="
echo ""

# Test 1: Source common library
test_source_common() {
    source src/lib/common.sh
}

# Test 2: Source prerequisites library  
test_source_prerequisites() {
    source src/lib/prerequisites.sh
}

# Test 3: Check color functions
test_color_functions() {
    source src/lib/common.sh
    progress "Test" >/dev/null
    success "Test" >/dev/null
    error "Test" 2>/dev/null
    warning "Test" >/dev/null
}

# Test 4: Check command_exists function
test_command_exists() {
    source src/lib/prerequisites.sh
    command_exists ls || return 1
    ! command_exists nonexistent_command_12345 || return 1
}

# Test 5: Test dry run detection
test_dry_run() {
    source src/lib/common.sh
    DRY_RUN=0 ! is_dry_run || return 1
    DRY_RUN=1 is_dry_run || return 1
}

# Run tests
echo "Unit Tests:"
run_test "Source common.sh" test_source_common
run_test "Source prerequisites.sh" test_source_prerequisites
run_test "Color functions" test_color_functions
run_test "command_exists function" test_command_exists
run_test "Dry run detection" test_dry_run

echo ""
echo "Script Tests:"

# Test help output
test_help() {
    ./wsl-alpine-build-minirootfs.sh --help >/dev/null 2>&1
}

run_test "Help command" test_help

# Summary
echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
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