#!/usr/bin/env bats
# Unit tests for minirootfs.sh library - ONLY MEANINGFUL TESTS
# Tests that verify OUR logic, not OS behavior

load ../test_helper

@test "minirootfs: library can be sourced" {
    run_command load_lib minirootfs
    assert_success
}

@test "minirootfs: get_minirootfs_url generates correct URL" {
    load_lib minirootfs
    
    # Our logic: URL generation
    run_command get_minirootfs_url "3.18.6" "x86_64"
    assert_success
    assert_output_equals "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.6-x86_64.tar.gz"
    
    run_command get_minirootfs_url "3.19.0" "aarch64"
    assert_success
    assert_output_equals "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-minirootfs-3.19.0-aarch64.tar.gz"
}

@test "minirootfs: get_checksum_url generates correct URL" {
    load_lib minirootfs
    
    # Our logic: checksum URL generation
    run_command get_checksum_url "3.18.6" "x86_64"
    assert_success
    assert_output_equals "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.6-x86_64.tar.gz.sha256"
}

@test "minirootfs: verify_extracted_fs validates filesystem structure" {
    load_lib minirootfs
    
    # Our logic: validate Alpine filesystem
    local test_rootfs="$TEST_TEMP_DIR/rootfs"
    create_test_rootfs "$test_rootfs"
    
    run_command verify_extracted_fs "$test_rootfs"
    assert_success
}

@test "minirootfs: verify_extracted_fs detects missing directories" {
    load_lib minirootfs
    
    # Our logic: detect invalid filesystem
    local test_rootfs="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$test_rootfs"
    # Missing required directories
    
    run_command verify_extracted_fs "$test_rootfs"
    assert_failure
    assert_output_contains "Missing essential directories"
}

# Note: We don't test actual download/extract operations as they require
# real network access and files. These are covered by integration testing
# in a real environment. The unit tests focus on URL generation, validation,
# and error handling which is what we actually control.
