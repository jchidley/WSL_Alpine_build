#!/usr/bin/env bats
# Unit tests for prerequisites checking

setup() {
    # Load the library
    source "${BATS_TEST_DIRNAME}/../../src/lib/prerequisites.sh"
    
    # Create temp directory for tests
    export TEST_TMPDIR="${BATS_TEST_TMPDIR}/prerequisites"
    mkdir -p "$TEST_TMPDIR"
}

teardown() {
    # Cleanup
    rm -rf "$TEST_TMPDIR"
}

@test "command_exists finds existing commands" {
    run command_exists "ls"
    [ "$status" -eq 0 ]
    
    run command_exists "bash"
    [ "$status" -eq 0 ]
}

@test "command_exists fails for non-existing commands" {
    run command_exists "this_command_does_not_exist_12345"
    [ "$status" -eq 1 ]
}

@test "check_prerequisites fails without wsl.exe" {
    # Mock command_exists to fail for wsl.exe
    command_exists() {
        [[ "$1" != "wsl.exe" ]]
    }
    
    run check_prerequisites
    [ "$status" -eq 1 ]
    [[ "$output" =~ "wsl.exe not found" ]]
}

@test "check_prerequisites detects missing commands" {
    # Save original function
    local original_exists=$(declare -f command_exists)
    
    # Mock to make fakeroot appear missing
    command_exists() {
        [[ "$1" != "fakeroot" ]]
    }
    
    run check_prerequisites
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Missing required commands: fakeroot" ]]
    
    # Restore original function
    eval "$original_exists"
}

@test "get_system_info runs without error" {
    # Just ensure it doesn't crash
    # Set VERBOSE to capture output
    VERBOSE=1
    output=$(get_system_info 2>&1)
    # Check that it outputs something
    [[ -n "$output" ]]
}