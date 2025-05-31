#!/usr/bin/env bats
# ABOUTME: Integration tests for wsl-alpine build command
# ABOUTME: Tests the new unified build system

load ../test_helper

setup() {
    export TEST_DIR="$BATS_TEST_TMPDIR/modular-test"
    export BUILD_DIR="$TEST_DIR/build"
    export OUTPUT_FILE="$TEST_DIR/test-alpine.tar.gz"
    export DRY_RUN=1
    
    mkdir -p "$TEST_DIR"
    
    # Path to the main script
    export SCRIPT="$BATS_TEST_DIRNAME/../../wsl-alpine"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "wsl-alpine script exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "wsl-alpine script sources required libraries" {
    # Check that the script contains the source commands
    grep -q "source.*common.sh" "$SCRIPT"
    grep -q "source.*minirootfs.sh" "$SCRIPT"
    grep -q "source.*wsl-operations.sh" "$SCRIPT"
    grep -q "source.*package.sh" "$SCRIPT"
}

@test "wsl-alpine shows help" {
    run "$SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alpine WSL Management Tool" ]]
    [[ "$output" =~ "Commands:" ]]
    [[ "$output" =~ "build" ]]
    [[ "$output" =~ "module" ]]
    [[ "$output" =~ "test" ]]
}

@test "wsl-alpine build shows help" {
    run "$SCRIPT" build --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Build Alpine WSL Distribution" ]]
    [[ "$output" =~ "--modules" ]]
    [[ "$output" =~ "--version" ]]
    [[ "$output" =~ "--arch" ]]
}

@test "wsl-alpine module list works" {
    run "$SCRIPT" module list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Available modules:" ]]
    [[ "$output" =~ "base" ]]
    [[ "$output" =~ "docker" ]]
}

@test "wsl-alpine module info works" {
    run "$SCRIPT" module info base
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Module: base" ]]
    [[ "$output" =~ "version:" ]]
    [[ "$output" =~ "description:" ]]
}

@test "wsl-alpine list works" {
    run "$SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WSL Distributions:" ]]
}

@test "wsl-alpine handles unknown commands" {
    # Test with an invalid command
    run "$SCRIPT" invalid-command
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Unknown command: invalid-command" ]]
}

@test "wsl-alpine version option works" {
    run "$SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alpine WSL Management Tool v" ]]
}

@test "wsl-alpine test command works" {
    # Test that the test command exists
    run "$SCRIPT" test --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Run Tests" ]]
}