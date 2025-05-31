#!/usr/bin/env bats
# Unit tests for common.sh library - ONLY MEANINGFUL TESTS
# Tests that verify OUR logic, not OS behavior

load ../test_helper

@test "common: library can be sourced" {
    run_command load_lib common
    assert_success
}

@test "common: logging functions work" {
    load_lib common
    
    # Test that our logging functions produce output
    run_command log_info "Test info message"
    assert_success
    assert_output_contains "Test info message"
    
    run_command log_error "Test error message"
    assert_success
    assert_output_contains "Test error message"
    
    run_command log_warning "Test warning message"
    assert_success
    assert_output_contains "Test warning message"
}

@test "common: debug logging controlled by DEBUG flag" {
    load_lib common
    
    # Our logic: only show debug when DEBUG=1
    run bash -c "export DEBUG=0; export QUIET_MODE=1; source '$LIB_DIR/common.sh' && log_debug 'Debug message' 2>&1"
    assert_success
    ! [[ "$output" =~ "Debug message" ]]
    
    run bash -c "export DEBUG=1; source '$LIB_DIR/common.sh' && log_debug 'Debug message' 2>&1"
    assert_success
    assert_output_includes "Debug message"
}

@test "common: verbose logging controlled by VERBOSE flag" {
    load_lib common
    
    # Our logic: only show verbose when VERBOSE=1
    run bash -c "export VERBOSE=0; export QUIET_MODE=1; source '$LIB_DIR/common.sh' && log_verbose 'Verbose message' 2>&1"
    assert_success
    ! [[ "$output" =~ "Verbose message" ]]
    
    run bash -c "export VERBOSE=1; source '$LIB_DIR/common.sh' && log_verbose 'Verbose message' 2>&1"
    assert_success
    assert_output_includes "Verbose message"
}

@test "common: dry run mode shows commands without executing" {
    load_lib common
    
    # Our logic: show what would be done in dry run mode
    DRY_RUN=0 run_command dry_run_exec echo "Test command"
    assert_success
    assert_output_includes "Test command"
    ! [[ "$output" =~ "[DRY RUN]" ]]
    
    DRY_RUN=1 run_command dry_run_exec echo "Test command"
    assert_success
    assert_output_includes "[DRY RUN] Would execute: echo Test command"
}

@test "common: die function exits with error" {
    load_lib common
    
    # Our logic: die should exit with status 1
    run_command bash -c 'source "$LIB_DIR/common.sh" && die "Fatal error"'
    assert_failure
    assert_output_contains "Fatal error"
}

@test "common: load_config loads environment variables" {
    load_lib common
    
    # Our logic: load variables from file
    cat > "$TEST_TEMP_DIR/test.env" << EOF
TEST_VAR=test_value
ANOTHER_VAR=another_value
EOF
    
    run_command bash -c "source '$LIB_DIR/common.sh' && load_config '$TEST_TEMP_DIR/test.env' && echo \"\$TEST_VAR:\$ANOTHER_VAR\""
    assert_success
    assert_output_contains "test_value:another_value"
}

@test "common: validate_distribution_name accepts valid names" {
    load_lib common
    
    # Our validation logic
    run_command validate_distribution_name "alpine"
    assert_success
    
    run_command validate_distribution_name "alpine-test"
    assert_success
    
    run_command validate_distribution_name "AlpineWSL123"
    assert_success
}

@test "common: validate_distribution_name rejects invalid names" {
    load_lib common
    
    # Our validation logic
    run_command validate_distribution_name "alpine@wsl"
    assert_failure
    assert_output_contains "only contain letters"
    
    run_command validate_distribution_name "alpine wsl"
    assert_failure
    
    run_command validate_distribution_name ""
    assert_failure
    
    # Test length limit
    run_command validate_distribution_name "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
    assert_failure
    assert_output_contains "64 characters or less"
}

@test "common: distribution_exists checks WSL distributions" {
    load_lib common
    
    # Our logic: parse WSL output to check existence
    # This tests our parsing logic, not WSL itself
    run_command distribution_exists "alp2"
    assert_success
    
    run_command distribution_exists "nonexistent"
    assert_failure
}

@test "common: get_wsl_distributions parses WSL output" {
    load_lib common
    
    # Our logic: parse and clean WSL output
    run_command get_wsl_distributions
    assert_success
    # Should return cleaned list of distributions
    assert_output_includes "alp2"
    assert_output_includes "Debian"
}

@test "common: find_wsl_exe locates WSL executable" {
    load_lib common
    
    # Our logic: search for wsl.exe in PATH
    run_command find_wsl_exe
    assert_success
    # Should set WSL_EXE variable
    [[ -n "$WSL_EXE" ]]
}

@test "common: command_exists checks command availability" {
    load_lib common
    
    # Our wrapper logic
    run_command command_exists "bash"
    assert_success
    
    run_command command_exists "nonexistent-command-xyz"
    assert_failure
}

@test "common: check_dependencies validates all dependencies" {
    load_lib common
    
    # Our logic: check multiple commands
    run_command check_dependencies "bash" "grep" "sed"
    assert_success
    
    run_command check_dependencies "bash" "nonexistent-command" "grep"
    assert_failure
    assert_output_includes "Missing required dependencies"
}

@test "common: setup_error_handling sets error trap" {
    load_lib common
    
    # Test that error trap is set and reports errors
    run_command bash -c "
        source '$LIB_DIR/common.sh'
        setup_error_handling
        false  # This should trigger the error handler
    "
    assert_failure
    assert_output_includes "Command failed"
    assert_output_includes "Failed command: false"
}