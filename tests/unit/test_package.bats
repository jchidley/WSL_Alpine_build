#!/usr/bin/env bats
# Unit tests for package.sh library - ONLY MEANINGFUL TESTS
# Tests that verify OUR logic, not APK behavior

load ../test_helper

@test "package: library can be sourced" {
    run_command load_lib package
    assert_success
}

@test "package: install_package_group handles unknown group" {
    load_lib package
    
    # Our logic: error on unknown package group
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$rootfs_dir"
    
    run_command install_package_group "$rootfs_dir" "nonexistent-group"
    assert_failure
    assert_output_contains "Unknown package group"
}

@test "package: install_package_group recognizes valid groups" {
    load_lib package
    
    # Our logic: validate known package groups
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$rootfs_dir"
    
    # These should be recognized (even if install is mocked)
    for group in base network development; do
        run_command install_package_group "$rootfs_dir" "$group"
        # Should not fail with "Unknown package group"
        ! [[ "$output" =~ "Unknown package group" ]]
    done
}

# Skip environment-dependent tests
@test "package: operations requiring real APK" {
    skip "Requires real APK package manager"
}

@test "package: database operations" {
    skip "Database operations require real APK database"
}

@test "package: cache operations" {
    skip "Cache operations require real filesystem"
}
