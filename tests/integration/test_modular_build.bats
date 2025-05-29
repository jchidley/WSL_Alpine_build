#!/usr/bin/env bats
# ABOUTME: Integration tests for modular Alpine WSL build script
# ABOUTME: Tests the refactored script with library dependencies

load ../test_helper

setup() {
    export TEST_DIR="$BATS_TEST_TMPDIR/modular-test"
    export BUILD_DIR="$TEST_DIR/build"
    export OUTPUT_FILE="$TEST_DIR/test-alpine.tar.gz"
    export DRY_RUN=1
    
    mkdir -p "$TEST_DIR"
    
    # Path to the modular script
    export SCRIPT="$BATS_TEST_DIRNAME/../../wsl-alpine-build-modular.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "modular script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "modular script sources required libraries" {
    # Check that the script contains the source commands
    grep -q "source.*common.sh" "$SCRIPT"
    grep -q "source.*prerequisites.sh" "$SCRIPT"
}

@test "modular script shows help" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Options:" ]]
    [[ "$output" =~ "--help" ]]
    [[ "$output" =~ "--verbose" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "modular script accepts command line arguments" {
    run "$SCRIPT" --dry-run --version 3.19.0 --arch aarch64 --name test-alpine
    [ "$status" -eq 0 ]
    # Script should complete successfully in dry-run mode
    [[ "$output" =~ "Build complete!" ]]
}

@test "modular script validates prerequisites" {
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Checking prerequisites" ]]
    [[ "$output" =~ "All prerequisites found" ]]
}

@test "modular script performs dry run correctly" {
    run "$SCRIPT" --dry-run --verbose
    [ "$status" -eq 0 ]
    
    # Check all major steps are shown
    [[ "$output" =~ "Checking prerequisites" ]]
    [[ "$output" =~ "Creating build directory" ]]
    [[ "$output" =~ "Downloading Alpine minirootfs" ]]
    [[ "$output" =~ "Extracting rootfs" ]]
    [[ "$output" =~ "Configuring Alpine for WSL" ]]
    [[ "$output" =~ "Packaging distribution" ]]
    [[ "$output" =~ "Build complete!" ]]
    
    # Check dry run indicators
    [[ "$output" =~ "[DRY RUN]" ]]
}

@test "modular script shows verbose output" {
    run "$SCRIPT" --dry-run --verbose
    [ "$status" -eq 0 ]
    
    # Check configuration display
    [[ "$output" =~ "Configuration:" ]]
    [[ "$output" =~ "Alpine Version:" ]]
    [[ "$output" =~ "Architecture:" ]]
    [[ "$output" =~ "Distribution Name:" ]]
    
    # Check verbose messages
    [[ "$output" =~ "[VERBOSE]" ]]
    [[ "$output" =~ "System information:" ]]
}

@test "modular script uses error handling from common.sh" {
    # Test with an invalid option to trigger error handling
    run "$SCRIPT" --invalid-option
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Unknown option: --invalid-option" ]]
}

@test "modular script respects environment variables" {
    export ALPINE_VERSION="3.20.0"
    export ARCH="armv7"
    export DISTRO_NAME="test-distro"
    
    run "$SCRIPT" --dry-run --verbose
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alpine Version: 3.20.0" ]]
    [[ "$output" =~ "Architecture: armv7" ]]
    [[ "$output" =~ "Distribution Name: test-distro" ]]
}

@test "modular script cleanup function works" {
    # The cleanup should be called even in dry-run mode
    # Don't override BUILD_DIR for this test
    unset BUILD_DIR
    run "$SCRIPT" --dry-run --verbose
    [ "$status" -eq 0 ]
    # Check for cleanup command in dry-run output
    echo "$output" | grep -q "rm -rf"
}