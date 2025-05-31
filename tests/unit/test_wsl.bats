#!/usr/bin/env bats
# Unit tests for wsl-operations.sh library - ONLY MEANINGFUL TESTS
# Tests that verify OUR logic, not WSL behavior

load ../test_helper

@test "wsl: library can be sourced" {
    run_command load_lib wsl-operations
    assert_success
}

@test "wsl: create_wsl_conf generates correct configuration" {
    load_lib wsl-operations
    
    # Our logic: generate WSL configuration
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc"
    
    # Test with defaults
    run_command create_wsl_conf "$rootfs_dir" "testuser" "false"
    assert_success
    
    # Verify configuration content
    assert_file_exists "$rootfs_dir/etc/wsl.conf"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[automount]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[network]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[interop]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[boot]"
    # Alpine always uses OpenRC, never systemd
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "systemd = false"
    # OpenRC boot command is needed to start services like Docker
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "command = /sbin/openrc default"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[user]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "default = testuser"
}

@test "wsl: create_wsl_distribution_conf creates distribution config" {
    load_lib wsl-operations
    
    # Our logic: create distribution-specific config
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc"
    
    run_command create_wsl_distribution_conf "$rootfs_dir" "test-distro"
    assert_success
    
    # Verify file
    assert_file_exists "$rootfs_dir/etc/wsl-distribution.conf"
    assert_file_contains "$rootfs_dir/etc/wsl-distribution.conf" "default = test-distro"
    assert_file_contains "$rootfs_dir/etc/wsl-distribution.conf" "command = /etc/oobe.sh"
}

@test "wsl: import_distribution validates inputs" {
    load_lib wsl-operations
    
    # Our validation logic: invalid distribution name
    run_command import_distribution "invalid@name" "/tmp/test.tar.gz"
    assert_failure
    assert_output_contains "only contain letters"
    
    # Our validation logic: non-existent archive
    run_command import_distribution "validname" "/tmp/nonexistent.tar.gz"
    assert_failure
    assert_output_contains "Archive file not found"
}

@test "wsl: get_wsl_version returns default version for unknown distros" {
    load_lib wsl-operations
    
    # Our logic: returns 2 as default for non-existent distribution
    run_command get_wsl_version "nonexistent"
    assert_success
    assert_output_equals "2"
}

@test "wsl: convert_wsl_version validates version number" {
    load_lib wsl-operations
    
    # Our validation logic: only 1 or 2 are valid
    run_command convert_wsl_version "alp2" "3"
    assert_failure
    assert_output_contains "Invalid WSL version"
    
    run_command convert_wsl_version "alp2" "0"
    assert_failure
    assert_output_contains "Invalid WSL version"
}

@test "wsl: package_rootfs validates rootfs exists" {
    load_lib wsl-operations
    
    # Our validation logic
    run_command package_rootfs "/tmp/nonexistent" "$TEST_TEMP_DIR/package.tar.gz"
    assert_failure
    assert_output_contains "not found"
}

@test "wsl: create_wsl_file validates input file" {
    load_lib wsl-operations
    
    # Our validation logic
    run_command create_wsl_file "/tmp/nonexistent.tar.gz"
    assert_failure
}

@test "wsl: wsl_supports_vhd checks for VHD support" {
    load_lib wsl-operations
    
    # Our logic: parse WSL help for VHD support
    run_command wsl_supports_vhd
    assert_success  # Mock includes --vhd in help
}

# Skip environment-dependent tests
@test "wsl: operations requiring real WSL" {
    skip_if_not_wsl
    # These tests would only run on real WSL systems
}

# Note: We don't test operations that require real WSL distributions as those
# depend on the Windows WSL subsystem. The unit tests focus on configuration
# generation, validation, and error handling which is what we actually control.
