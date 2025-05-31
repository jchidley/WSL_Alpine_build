#!/usr/bin/env bats
# Unit tests for wsl.sh library

load ../test_helper

@test "wsl: library can be sourced" {
    run_command load_lib wsl-operations
    assert_success
}

@test "wsl: create_wsl_conf generates correct configuration" {
    load_lib wsl-operations
    
    # Create test rootfs
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc"
    
    # Create config with defaults
    run_command create_wsl_conf "$rootfs_dir" "testuser" "false"
    assert_success
    assert_output_contains "WSL configuration created"
    
    # Verify file exists
    assert_file_exists "$rootfs_dir/etc/wsl.conf"
    
    # Check content
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[automount]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[network]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[interop]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[boot]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "systemd = false"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "[user]"
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "default = testuser"
}

@test "wsl: create_wsl_conf with systemd enabled" {
    load_lib wsl-operations
    
    # Create test rootfs
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc"
    
    # Create config with systemd
    run_command create_wsl_conf "$rootfs_dir" "" "true"
    assert_success
    
    # Check systemd is enabled
    assert_file_contains "$rootfs_dir/etc/wsl.conf" "systemd = true"
    
    # Should not have openrc command
    ! grep -q "command = /sbin/openrc" "$rootfs_dir/etc/wsl.conf"
}

@test "wsl: create_wsl_distribution_conf creates distribution config" {
    load_lib wsl-operations
    
    # Create test rootfs
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc"
    
    # Create distribution config
    run_command create_wsl_distribution_conf "$rootfs_dir" "test-distro"
    assert_success
    assert_output_contains "WSL distribution configuration created"
    
    # Verify file
    assert_file_exists "$rootfs_dir/etc/wsl-distribution.conf"
    assert_file_contains "$rootfs_dir/etc/wsl-distribution.conf" "default = test-distro"
    assert_file_contains "$rootfs_dir/etc/wsl-distribution.conf" "command = /etc/oobe.sh"
}

@test "wsl: import_distribution validates inputs" {
    load_lib wsl-operations
    
    # Test with invalid distribution name
    run_command import_distribution "invalid@name" "/tmp/test.tar.gz"
    assert_failure
    assert_output_contains "only contain letters"
    
    # Test with non-existent archive
    run_command import_distribution "validname" "/tmp/nonexistent.tar.gz"
    assert_failure
    assert_output_contains "Archive file not found"
}

@test "wsl: import_distribution detects existing distribution" {
    load_lib wsl-operations
    
    # Create test archive
    local test_archive="$TEST_TEMP_DIR/test.tar.gz"
    touch "$test_archive"
    
    # Try to import existing distribution
    run_command import_distribution "alp2" "$test_archive"
    assert_failure
    assert_output_contains "already exists"
}

@test "wsl: import_distribution with valid inputs" {
    load_lib wsl-operations
    
    # Create test archive
    local test_archive="$TEST_TEMP_DIR/test.tar.gz"
    touch "$test_archive"
    
    # Import new distribution
    run_command import_distribution "newdistro" "$test_archive"
    assert_success
    assert_output_contains "Distribution imported successfully"
    assert_output_contains "Importing distribution: newdistro"
}

@test "wsl: export_distribution validates distribution exists" {
    load_lib wsl-operations
    
    # Try to export non-existent distribution
    run_command export_distribution "nonexistent" "$TEST_TEMP_DIR/export.tar"
    assert_failure
    assert_output_contains "not found"
}

@test "wsl: export_distribution with valid distribution" {
    load_lib wsl-operations
    
    # Export existing distribution
    run_command export_distribution "alp2" "$TEST_TEMP_DIR/export.tar"
    assert_success
    assert_output_contains "Distribution exported successfully"
    assert_output_contains "Exporting distribution: alp2"
}

@test "wsl: unregister_distribution removes distribution" {
    load_lib wsl-operations
    
    # Unregister existing distribution
    run_command unregister_distribution "alp2"
    assert_success
    assert_output_contains "Distribution unregistered successfully"
    assert_output_contains "Unregistering distribution: alp2"
}

@test "wsl: unregister_distribution handles non-existent distribution" {
    load_lib wsl-operations
    
    # Try to unregister non-existent distribution
    run_command unregister_distribution "nonexistent"
    assert_failure
    assert_output_contains "not found"
}

@test "wsl: get_wsl_version returns version" {
    load_lib wsl-operations
    
    # Get version of existing distribution
    run_command get_wsl_version "alp2"
    assert_success
    assert_output_equals "2"
}

@test "wsl: convert_wsl_version validates version" {
    load_lib wsl-operations
    
    # Invalid version
    run_command convert_wsl_version "alp2" "3"
    assert_failure
    assert_output_contains "Invalid WSL version"
    
    # Valid version
    run_command convert_wsl_version "alp2" "1"
    assert_success
    assert_output_contains "Setting WSL version"
}

@test "wsl: list_distributions_detailed shows distributions" {
    load_lib wsl-operations
    
    run_command list_distributions_detailed
    assert_success
    assert_output_contains "WSL Distributions:"
    assert_output_contains "Debian"
    assert_output_contains "alp2"
}

@test "wsl: run_in_distribution validates distribution" {
    load_lib wsl-operations
    
    # Non-existent distribution
    run_command run_in_distribution "nonexistent" echo "test"
    assert_failure
    assert_output_contains "not found"
    
    # Existing distribution
    run_command run_in_distribution "alp2" echo "test"
    assert_success
    assert_output_contains "Running in distribution: alp2"
    assert_output_contains "test"
}

@test "wsl: package_rootfs creates archive" {
    skip_if_missing_command tar
    skip_if_missing_command gzip
    
    load_lib wsl-operations
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Package it
    local output_file="$TEST_TEMP_DIR/package.tar.gz"
    run_command package_rootfs "$rootfs_dir" "$output_file"
    assert_success
    assert_output_contains "Root filesystem packaged successfully"
    
    # Verify archive
    assert_file_exists "$output_file"
    
    # Check it's a valid tar.gz
    run_command tar -tzf "$output_file"
    assert_success
}

@test "wsl: package_rootfs handles missing rootfs" {
    load_lib wsl-operations
    
    # Try to package non-existent directory
    run_command package_rootfs "/tmp/nonexistent" "$TEST_TEMP_DIR/package.tar.gz"
    assert_failure
    assert_output_contains "not found"
}

@test "wsl: create_wsl_file creates WSL installable file" {
    load_lib wsl-operations
    
    # Create test tar file
    local tar_file="$TEST_TEMP_DIR/test.tar.gz"
    echo "test content" > "$tar_file"
    
    # Create WSL file
    run_command create_wsl_file "$tar_file"
    assert_success
    assert_output_contains "Created WSL file"
    
    # Verify WSL file
    assert_file_exists "$TEST_TEMP_DIR/test.wsl"
}

@test "wsl: wsl_supports_vhd detects VHD support" {
    load_lib wsl-operations
    
    # Our mock wsl.exe includes --vhd in help
    run_command wsl_supports_vhd
    assert_success
}

@test "wsl: cleanup_wsl_install_dirs removes directories" {
    load_lib wsl-operations
    
    # Create test directories
    mkdir -p "$TEST_TEMP_DIR/wsl/testdistro"
    
    # Mock get_real_home and get_windows_username
    export -f get_real_home
    export -f get_windows_username
    get_real_home() { echo "$TEST_TEMP_DIR"; }
    get_windows_username() { echo "testuser"; }
    
    # Run cleanup
    run_command cleanup_wsl_install_dirs "testdistro"
    assert_success
    
    # Directory should be removed
    [[ ! -d "$TEST_TEMP_DIR/wsl/testdistro" ]]
}