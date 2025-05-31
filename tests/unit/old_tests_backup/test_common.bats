#!/usr/bin/env bats
# Unit tests for common.sh library

load ../test_helper

@test "common: library can be sourced" {
    run_command load_lib common
    assert_success
}

@test "common: logging functions work" {
    load_lib common
    
    # Test each logging function
    run_command log_info "Test info message"
    assert_success
    assert_output_contains "Test info message"
    
    run_command log_success "Test success message"
    assert_success
    assert_output_contains "Test success message"
    
    run_command log_error "Test error message"
    assert_success
    assert_output_contains "Test error message"
    
    run_command log_warning "Test warning message"
    assert_success
    assert_output_contains "Test warning message"
    
    run_command log_progress "Test progress message"
    assert_success
    assert_output_contains "Test progress message"
}

@test "common: debug logging only shows when DEBUG=1" {
    load_lib common
    
    # Test with DEBUG=0 - should not produce output
    run bash -c "export DEBUG=0; export QUIET_MODE=1; source '$LIB_DIR/common.sh' && log_debug 'Debug message' 2>&1"
    assert_success
    # Output should be empty or not contain the debug message
    ! [[ "$output" =~ "Debug message" ]]
    
    # Test with DEBUG=1 - should produce output
    run bash -c "export DEBUG=1; source '$LIB_DIR/common.sh' && log_debug 'Debug message' 2>&1"
    assert_success
    assert_output_includes "Debug message"
}

@test "common: verbose logging only shows when VERBOSE=1" {
    load_lib common
    
    # Test with VERBOSE=0 - should not produce output
    run bash -c "export VERBOSE=0; export QUIET_MODE=1; source '$LIB_DIR/common.sh' && log_verbose 'Verbose message' 2>&1"
    assert_success
    # Output should be empty or not contain the verbose message
    ! [[ "$output" =~ "Verbose message" ]]
    
    # Test with VERBOSE=1 - should produce output
    run bash -c "export VERBOSE=1; source '$LIB_DIR/common.sh' && log_verbose 'Verbose message' 2>&1"
    assert_success
    assert_output_includes "Verbose message"
}

@test "common: dry run mode works" {
    load_lib common
    
    # Test normal mode
    DRY_RUN=0 run_command dry_run_exec echo "Test command"
    assert_success
    assert_output_includes "Test command"
    
    # Test dry run mode
    DRY_RUN=1 run_command dry_run_exec echo "Test command"
    assert_success
    assert_output_includes "[DRY RUN] Would execute: echo Test command"
}

@test "common: die function exits with error" {
    load_lib common
    
    run_command bash -c 'source "$LIB_DIR/common.sh" && die "Fatal error"'
    assert_failure
    assert_output_contains "Fatal error"
}

@test "common: load_config loads environment file" {
    load_lib common
    
    # Create test .env file
    cat > "$TEST_TEMP_DIR/.env" << EOF
TEST_VAR=test_value
ANOTHER_VAR=another_value
EOF
    
    # Load config
    run_command bash -c "source '$LIB_DIR/common.sh' && load_config '$TEST_TEMP_DIR/.env' && echo \$TEST_VAR"
    assert_success
    assert_output_contains "test_value"
}

@test "common: load_config sets defaults" {
    load_lib common
    
    # Create minimal .env file
    echo "" > "$TEST_TEMP_DIR/.env"
    
    # Load config and check defaults
    run_command bash -c "source '$LIB_DIR/common.sh' && load_config '$TEST_TEMP_DIR/.env' && echo \$WSL_DISTRIBUTION_NAME"
    assert_success
    assert_output_contains "alp2"
}

@test "common: command_exists function works" {
    load_lib common
    
    # Test existing command
    run_command command_exists bash
    assert_success
    
    # Test non-existing command
    run_command command_exists nonexistentcommand12345
    assert_failure
}

@test "common: check_dependencies validates all dependencies" {
    load_lib common
    
    # Test with existing commands
    run_command check_dependencies bash sh echo
    assert_success
    
    # Test with non-existing command
    run_command check_dependencies bash nonexistentcommand12345
    assert_failure
    assert_output_contains "Missing required dependencies"
}

@test "common: validate_distribution_name accepts valid names" {
    load_lib common
    
    # Valid names
    run_command validate_distribution_name "alpine"
    assert_success
    
    run_command validate_distribution_name "alpine-wsl"
    assert_success
    
    run_command validate_distribution_name "test_distro_123"
    assert_success
}

@test "common: validate_distribution_name rejects invalid names" {
    load_lib common
    
    # Empty name
    run_command validate_distribution_name ""
    assert_failure
    assert_output_contains "cannot be empty"
    
    # Invalid characters
    run_command validate_distribution_name "alpine@wsl"
    assert_failure
    assert_output_contains "only contain letters"
    
    # Too long name
    local long_name="verylongdistributionnamethatshouldnotbeallowedverylongdistributionname"
    run_command validate_distribution_name "$long_name"
    assert_failure
    assert_output_contains "64 characters or less"
}

@test "common: get_real_home returns correct home directory" {
    load_lib common
    
    # Test as non-root user - function should return a home directory
    run bash -c "export USER=testuser; export SUDO_USER=; source '$LIB_DIR/common.sh' && get_real_home"
    assert_success
    # Should return some form of home directory
    assert_output_includes "/home/"
    
    # Test as root
    run bash -c "export USER=root; export SUDO_USER=; source '$LIB_DIR/common.sh' && get_real_home"
    assert_success
    assert_output_includes "/root"
}

@test "common: find_wsl_exe locates WSL executable" {
    load_lib common
    
    # With our mock wsl.exe
    run_command find_wsl_exe
    assert_success
    [[ -n "$WSL_EXE" ]]
}

@test "common: distribution_exists checks WSL distributions" {
    load_lib common
    
    # Test existing distribution
    run_command distribution_exists "alp2"
    assert_success
    
    # Test non-existing distribution
    run_command distribution_exists "nonexistent"
    assert_failure
}

@test "common: get_wsl_distributions lists distributions" {
    load_lib common
    
    run_command get_wsl_distributions
    assert_success
    assert_output_contains "alp2"
    assert_output_contains "Debian"
}

@test "common: safe_remove_file removes files safely" {
    load_lib common
    
    # Create test file
    local test_file="$TEST_TEMP_DIR/test.txt"
    echo "test" > "$test_file"
    
    # Remove file
    run_command safe_remove_file "$test_file"
    assert_success
    assert_output_contains "Removed file"
    
    # File should not exist
    [[ ! -f "$test_file" ]]
    
    # Try removing non-existent file (should succeed)
    run_command safe_remove_file "$test_file"
    assert_success
}

@test "common: safe_remove_dir removes directories safely" {
    load_lib common
    
    # Create test directory
    local test_dir="$TEST_TEMP_DIR/testdir"
    mkdir -p "$test_dir/subdir"
    touch "$test_dir/file.txt"
    
    # Remove directory
    run_command safe_remove_dir "$test_dir"
    assert_success
    assert_output_contains "Removed directory"
    
    # Directory should not exist
    [[ ! -d "$test_dir" ]]
    
    # Try removing non-existent directory (should succeed)
    run_command safe_remove_dir "$test_dir"
    assert_success
}

@test "common: create_temp_dir creates temporary directory" {
    load_lib common
    
    # Create temp dir with default prefix
    run bash -c "export DEBUG=0; source '$LIB_DIR/common.sh' && create_temp_dir 2>/dev/null"
    assert_success
    
    # Extract just the directory path from output (last line)
    local temp_dir
    temp_dir=$(echo "$output" | tail -n1)
    
    # Verify it's a valid temp directory
    [[ "$temp_dir" =~ /tmp/alpine-wsl\..* ]]
    [[ -d "$temp_dir" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "common: create_temp_dir with custom prefix" {
    load_lib common
    
    # Create temp dir with custom prefix
    run bash -c "export DEBUG=0; source '$LIB_DIR/common.sh' && create_temp_dir 'test-prefix' 2>/dev/null"
    assert_success
    
    # Extract just the directory path from output (last line)
    local temp_dir
    temp_dir=$(echo "$output" | tail -n1)
    
    # Verify it's a valid temp directory
    [[ "$temp_dir" =~ /tmp/test-prefix\..* ]]
    [[ -d "$temp_dir" ]]
    
    # Cleanup
    rm -rf "$temp_dir"
}

@test "common: setup_error_handling sets error trap" {
    load_lib common
    
    # Test that error handling catches failures
    run_command bash -c "source '$LIB_DIR/common.sh' && setup_error_handling && false"
    assert_failure
    assert_output_contains "Command failed"
}