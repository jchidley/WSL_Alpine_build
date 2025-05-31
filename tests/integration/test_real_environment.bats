#!/usr/bin/env bats
# Integration tests that require real WSL/network/system resources
# These should only run when explicitly requested or in appropriate environments

load ../test_helper

# Setup for integration tests
setup() {
    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/alpine-wsl-integration-test.XXXXXX")
    export TEST_TEMP_DIR
}

# Helper to check if integration tests should run
require_integration_tests() {
    if [[ -z "${RUN_INTEGRATION_TESTS:-}" ]]; then
        skip "Set RUN_INTEGRATION_TESTS=1 to run integration tests"
    fi
}

@test "integration: real WSL distribution operations" {
    require_integration_tests
    skip_if_not_wsl
    
    # Test with real WSL
    load_lib wsl-operations
    
    # This would test real WSL operations
    run_command bash -c "wsl.exe --list --quiet | head -1"
    assert_success
}

@test "integration: real minirootfs download" {
    require_integration_tests
    skip_if_missing_command wget
    
    load_lib minirootfs
    
    # Test downloading a small test file
    local test_url="https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.6-x86_64.tar.gz.sha256"
    local output_file="$TEST_TEMP_DIR/test.sha256"
    
    run_command wget -q -O "$output_file" "$test_url"
    assert_success
    assert_file_exists "$output_file"
}

@test "integration: full build workflow with real components" {
    require_integration_tests
    skip_if_not_wsl
    skip_if_ci  # Too heavy for CI
    
    # This would be a real end-to-end test
    run_command "$PROJECT_ROOT/wsl-alpine" build \
        --name "test-alpine-$$" \
        --modules base \
        --dry-run
    
    assert_success
}

@test "integration: real APK operations in Alpine container" {
    require_integration_tests
    skip_if_missing_command docker
    
    # Use Docker to test real APK operations
    run_command docker run --rm alpine:3.18 apk update
    assert_success
    assert_output_contains "fetch"
}

@test "integration: real WSL version operations" {
    require_integration_tests
    skip_if_not_wsl
    
    load_lib wsl-operations
    
    # Test getting version of real distribution
    if distribution_exists "Debian"; then
        run_command get_wsl_version "Debian"
        assert_success
        [[ "$output" =~ ^[12]$ ]]
    else
        skip "No Debian distribution for testing"
    fi
}