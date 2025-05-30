#!/usr/bin/env bats
# Unit tests for minirootfs.sh library

load ../test_helper

@test "minirootfs: library can be sourced" {
    run_command load_lib minirootfs
    assert_success
}

@test "minirootfs: get_minirootfs_url generates correct URL" {
    load_lib minirootfs
    
    # Test with default values
    run_command get_minirootfs_url
    assert_success
    assert_output_contains "alpine-minirootfs"
    assert_output_contains ".tar.gz"
    
    # Test with specific version and arch
    run_command get_minirootfs_url "3.19.0" "aarch64"
    assert_success
    assert_output_equals "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-minirootfs-3.19.0-aarch64.tar.gz"
}

@test "minirootfs: get_checksum_url generates correct URL" {
    load_lib minirootfs
    
    # Test with default values
    run_command get_checksum_url
    assert_success
    assert_output_contains ".sha256"
    
    # Test with specific version and arch
    run_command get_checksum_url "3.19.0" "x86_64"
    assert_success
    assert_output_equals "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz.sha256"
}

@test "minirootfs: download_with_cache creates cache directory" {
    load_lib minirootfs
    
    # Mock wget
    mock_wget
    
    # Set custom cache dir
    export CACHE_DIR="$TEST_TEMP_DIR/cache"
    
    # Download file
    local test_url="https://example.com/test.tar.gz"
    local output_file="$TEST_TEMP_DIR/test.tar.gz"
    
    run_command download_with_cache "$test_url" "$output_file"
    assert_success
    assert_dir_exists "$CACHE_DIR"
    assert_file_exists "$output_file"
}

@test "minirootfs: download_with_cache uses cached file" {
    load_lib minirootfs
    
    # Set custom cache dir
    export CACHE_DIR="$TEST_TEMP_DIR/cache"
    mkdir -p "$CACHE_DIR"
    
    # Create cached file
    echo "cached content" > "$CACHE_DIR/test.tar.gz"
    
    # Download file (should use cache)
    local test_url="https://example.com/test.tar.gz"
    local output_file="$TEST_TEMP_DIR/test.tar.gz"
    
    run_command download_with_cache "$test_url" "$output_file"
    assert_success
    assert_output_contains "Using cached file"
    assert_file_exists "$output_file"
    
    # Verify content matches cache
    [[ "$(cat "$output_file")" == "cached content" ]]
}

@test "minirootfs: verify_checksum validates correctly" {
    load_lib minirootfs
    
    # Create test file
    local test_file="$TEST_TEMP_DIR/test.tar.gz"
    echo "test content" > "$test_file"
    
    # Create correct checksum
    local checksum_file="$TEST_TEMP_DIR/test.tar.gz.sha256"
    (cd "$TEST_TEMP_DIR" && sha256sum "test.tar.gz" > "test.tar.gz.sha256")
    
    # Test successful verification
    run_command verify_checksum "$test_file" "$checksum_file"
    assert_success
    assert_output_contains "Checksum verified"
}

@test "minirootfs: verify_checksum fails on mismatch" {
    load_lib minirootfs
    
    # Create test file
    local test_file="$TEST_TEMP_DIR/test.tar.gz"
    echo "test content" > "$test_file"
    
    # Create incorrect checksum
    local checksum_file="$TEST_TEMP_DIR/test.tar.gz.sha256"
    echo "wrongchecksum123  test.tar.gz" > "$checksum_file"
    
    # Test failed verification
    run_command verify_checksum "$test_file" "$checksum_file"
    assert_failure
    assert_output_contains "Checksum verification failed"
}

@test "minirootfs: extract_minirootfs extracts archive" {
    load_lib minirootfs
    
    # Create test minirootfs
    local test_archive
    test_archive=$(create_test_minirootfs)
    
    # Extract it
    local extract_dir="$TEST_TEMP_DIR/extracted"
    run_command extract_minirootfs "$test_archive" "$extract_dir"
    assert_success
    assert_output_contains "Root filesystem extracted successfully"
    
    # Verify extraction
    assert_dir_exists "$extract_dir"
    assert_dir_exists "$extract_dir/etc"
    assert_dir_exists "$extract_dir/bin"
}

@test "minirootfs: extract_minirootfs creates target directory" {
    load_lib minirootfs
    
    # Create test minirootfs
    local test_archive
    test_archive=$(create_test_minirootfs)
    
    # Extract to non-existent directory
    local extract_dir="$TEST_TEMP_DIR/new_dir/extracted"
    run_command extract_minirootfs "$test_archive" "$extract_dir"
    assert_success
    assert_dir_exists "$extract_dir"
}

@test "minirootfs: verify_extracted_fs validates filesystem" {
    load_lib minirootfs
    
    # Create valid rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Test successful verification
    run_command verify_extracted_fs "$rootfs_dir"
    assert_success
    assert_output_contains "Filesystem verification passed"
}

@test "minirootfs: verify_extracted_fs detects missing directories" {
    load_lib minirootfs
    
    # Create incomplete rootfs
    local rootfs_dir="$TEST_TEMP_DIR/incomplete"
    mkdir -p "$rootfs_dir"/{etc,bin}
    # Missing sbin, usr, var, lib
    
    # Test failed verification
    run_command verify_extracted_fs "$rootfs_dir"
    assert_failure
    assert_output_contains "Missing essential directories"
}

@test "minirootfs: configure_apk_repos creates repository file" {
    load_lib minirootfs
    
    # Create test rootfs
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir/etc/apk"
    
    # Configure repos
    run_command configure_apk_repos "$rootfs_dir" "3.18.6"
    assert_success
    assert_output_contains "APK repositories configured"
    
    # Verify repo file
    assert_file_exists "$rootfs_dir/etc/apk/repositories"
    assert_file_contains "$rootfs_dir/etc/apk/repositories" "v3.18/main"
    assert_file_contains "$rootfs_dir/etc/apk/repositories" "v3.18/community"
    assert_file_contains "$rootfs_dir/etc/apk/repositories" "@testing"
}

@test "minirootfs: cleanup_for_wsl prepares filesystem" {
    load_lib minirootfs
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Add files to clean
    touch "$rootfs_dir/etc/resolv.conf"
    touch "$rootfs_dir/etc/machine-id"
    mkdir -p "$rootfs_dir/var/cache/apk"
    touch "$rootfs_dir/var/cache/apk/test"
    
    # Run cleanup
    run_command cleanup_for_wsl "$rootfs_dir"
    assert_success
    assert_output_contains "Filesystem cleaned up for WSL"
    
    # Verify cleanup
    [[ ! -f "$rootfs_dir/etc/resolv.conf" ]]
    [[ ! -f "$rootfs_dir/etc/machine-id" ]]
    [[ -d "$rootfs_dir/tmp" ]]
    [[ "$(stat -c %a "$rootfs_dir/tmp")" == "1777" ]]
}

@test "minirootfs: prepare_minirootfs full workflow" {
    skip_if_missing_command wget
    skip_if_missing_command tar
    
    load_lib minirootfs
    
    # Mock wget to avoid actual downloads
    mock_wget
    
    # Prepare minirootfs
    local target_dir="$TEST_TEMP_DIR/alpine"
    local work_dir="$TEST_TEMP_DIR/work"
    
    # This test simulates the full workflow but with mocked downloads
    run_command bash -c "
        source '$LIB_DIR/minirootfs.sh'
        # Override download function to use test archive
        download_minirootfs() {
            local test_archive
            test_archive=\$(create_test_minirootfs)
            echo \"\$test_archive\"
        }
        prepare_minirootfs '3.18.6' 'x86_64' '$target_dir' '$work_dir'
    "
    
    assert_success
    assert_output_contains "Minirootfs prepared successfully"
    assert_dir_exists "$target_dir"
}