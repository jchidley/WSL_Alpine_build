#!/usr/bin/env bats
# Unit tests for package.sh library - ONLY MEANINGFUL TESTS
# Tests that verify OUR logic, not APK behavior

load ../test_helper

@test "package: library can be sourced" {
    run_command load_lib package
    assert_success
}

@test "package: install_packages validates input" {
    load_lib package
    
    # Our logic: handle empty package list
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$rootfs_dir"
    
    # Empty package list should succeed (no-op)
    run_command install_packages "$rootfs_dir" ""
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

@test "package: fix_package_db handles corrupted database" {
    load_lib package
    
    # Our recovery logic
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$rootfs_dir"
    
    # Create corrupted database
    mkdir -p "$rootfs_dir/lib/apk/db"
    echo "corrupted" > "$rootfs_dir/lib/apk/db/installed"
    
    run_command fix_package_db "$rootfs_dir"
    assert_success
    assert_output_contains "Fixing package database"
}

@test "package: cleanup_package_cache removes cache files" {
    load_lib package
    
    # Our cleanup logic
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$rootfs_dir"
    
    # Create cache files
    mkdir -p "$rootfs_dir/var/cache/apk"
    touch "$rootfs_dir/var/cache/apk/cache1" "$rootfs_dir/var/cache/apk/cache2"
    
    run_command cleanup_package_cache "$rootfs_dir"
    assert_success
    
    # Cache should be cleaned
    [[ -z "$(ls -A "$rootfs_dir/var/cache/apk" 2>/dev/null)" ]]
}

# Skip environment-dependent tests
@test "package: operations requiring real APK" {
    skip "Requires real APK package manager"
}