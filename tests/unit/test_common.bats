#!/usr/bin/env bats
# Unit tests for common functions

setup() {
    # Load test helper
    load ../test_helper
    
    # Load the library
    source "${LIB_DIR}/common.sh"
    
    # Reset globals
    export DEBUG=0
    export VERBOSE=0
    export DRY_RUN=0
}

@test "progress function outputs correctly" {
    # Don't use 'run' for functions that output to stdout
    output=$(progress "Test message" 2>&1)
    # Strip ANSI escape codes for testing
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "→ Test message" ]]
}

@test "success function outputs correctly" {
    output=$(success "Operation completed" 2>&1)
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "✓ Operation completed" ]]
}

@test "error function outputs to stderr" {
    output=$(error "Something went wrong" 2>&1)
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "✗ Something went wrong" ]]
}

@test "warning function outputs correctly" {
    output=$(warning "This is a warning" 2>&1)
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "⚠ This is a warning" ]]
}

@test "debug messages only show when DEBUG=1" {
    DEBUG=0
    output=$(debug "Debug message" 2>&1)
    [ -z "$output" ]
    
    DEBUG=1
    output=$(debug "Debug message" 2>&1)
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "[DEBUG] Debug message" ]]
}

@test "verbose messages only show when VERBOSE=1" {
    VERBOSE=0
    output=$(verbose "Verbose message" 2>&1)
    [ -z "$output" ]
    
    VERBOSE=1
    output=$(verbose "Verbose message" 2>&1)
    clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$clean_output" == "[VERBOSE] Verbose message" ]]
}

@test "is_dry_run returns correct status" {
    DRY_RUN=0
    run is_dry_run
    [ "$status" -eq 1 ]
    
    DRY_RUN=1
    run is_dry_run
    [ "$status" -eq 0 ]
}

@test "dry_run_exec shows commands in dry run mode" {
    DRY_RUN=1
    run dry_run_exec echo "Hello"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[DRY RUN] Would execute: echo Hello" ]]
}

@test "dry_run_exec executes commands when not in dry run mode" {
    DRY_RUN=0
    run dry_run_exec echo "Hello"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello" ]
}