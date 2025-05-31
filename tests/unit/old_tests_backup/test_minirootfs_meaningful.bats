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

@test "minirootfs: verify_checksum validates correctly" {
    skip_if_missing_command sha256sum
    load_lib minirootfs
    
    # Our logic: checksum validation
    # Create test file and checksum
    local test_file="$TEST_TEMP_DIR/test.tar.gz"
    echo "test content" > "$test_file"
    (cd "$TEST_TEMP_DIR" && sha256sum "test.tar.gz" > "test.tar.gz.sha256")
    
    # Should pass with correct checksum
    run_command verify_checksum "$test_file"
    assert_success
}

@test "minirootfs: verify_checksum fails on mismatch" {
    skip_if_missing_command sha256sum
    load_lib minirootfs
    
    # Our logic: detect checksum mismatch
    # Create test file with wrong checksum
    local test_file="$TEST_TEMP_DIR/test.tar.gz"
    echo "test content" > "$test_file"
    echo "wrongchecksum  test.tar.gz" > "$test_file.sha256"
    
    run_command verify_checksum "$test_file"
    assert_failure
    assert_output_contains "Checksum verification failed"
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
    assert_output_contains "Missing required directory"
}

@test "minirootfs: configure_apk_repos generates correct configuration" {
    load_lib minirootfs
    
    # Our logic: generate APK repository configuration
    local test_rootfs="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$test_rootfs/etc/apk"
    
    run_command configure_apk_repos "$test_rootfs" "3.18"
    assert_success
    
    # Check configuration was created
    assert_file_exists "$test_rootfs/etc/apk/repositories"
    assert_file_contains "$test_rootfs/etc/apk/repositories" "https://dl-cdn.alpinelinux.org/alpine/v3.18/main"
    assert_file_contains "$test_rootfs/etc/apk/repositories" "https://dl-cdn.alpinelinux.org/alpine/v3.18/community"
}

@test "minirootfs: create_apk_world creates world file" {
    load_lib minirootfs
    
    # Our logic: create APK world file
    local test_rootfs="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$test_rootfs/etc/apk"
    
    run_command create_apk_world "$test_rootfs"
    assert_success
    
    assert_file_exists "$test_rootfs/etc/apk/world"
    assert_file_contains "$test_rootfs/etc/apk/world" "alpine-base"
}

# Skip environment-dependent tests in mock environment
@test "minirootfs: download operations" {
    skip "Download tests require network access"
}

@test "minirootfs: extract operations" {
    skip "Extract tests require real tar files"
}