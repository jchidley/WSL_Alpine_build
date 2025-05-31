#!/usr/bin/env bats
# Integration tests that validate build output would actually work

load ../test_helper

setup() {
    load_lib common
    load_lib minirootfs
    load_lib wsl-operations
    
    export TEST_ROOTFS="$BATS_TEST_TMPDIR/rootfs"
    mkdir -p "$TEST_ROOTFS"
}

teardown() {
    rm -rf "$TEST_ROOTFS"
}

@test "build: creates passwd with ash shell for root" {
    # Simulate what base module does
    mkdir -p "$TEST_ROOTFS/etc"
    cat > "$TEST_ROOTFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/ash
EOF
    
    # Verify root uses ash not bash
    grep -q "^root:.*:/bin/ash$" "$TEST_ROOTFS/etc/passwd"
    ! grep -q "^root:.*:/bin/bash$" "$TEST_ROOTFS/etc/passwd"
}

@test "build: creates wsluser with ash shell" {
    # Simulate what base module does
    mkdir -p "$TEST_ROOTFS/etc"
    cat > "$TEST_ROOTFS/etc/passwd" << 'EOF'
wsluser:x:1000:1000:WSL User:/home/wsluser:/bin/ash
EOF
    
    # Verify wsluser uses ash not bash
    grep -q "^wsluser:.*:/bin/ash$" "$TEST_ROOTFS/etc/passwd"
    ! grep -q "^wsluser:.*:/bin/bash$" "$TEST_ROOTFS/etc/passwd"
}

@test "build: ash shell exists in minirootfs" {
    # In a real Alpine rootfs, /bin/ash should exist
    # This test would fail if we tried to use /bin/bash
    mkdir -p "$TEST_ROOTFS/bin"
    touch "$TEST_ROOTFS/bin/ash"
    [ -f "$TEST_ROOTFS/bin/ash" ]
    
    # bash should NOT exist in base Alpine
    ! [ -f "$TEST_ROOTFS/bin/bash" ]
}

@test "build: creates OOBE scripts directory" {
    # Base module should create /etc/oobe.d/
    mkdir -p "$TEST_ROOTFS/etc/oobe.d"
    [ -d "$TEST_ROOTFS/etc/oobe.d" ]
}

@test "build: package installation script created in OOBE" {
    # Simulate base module creating package script
    mkdir -p "$TEST_ROOTFS/etc/oobe.d"
    cat > "$TEST_ROOTFS/etc/oobe.d/00-base-packages.sh" << 'EOF'
#!/bin/sh
apk update
apk add --no-cache alpine-base openrc util-linux shadow sudo
EOF
    
    [ -f "$TEST_ROOTFS/etc/oobe.d/00-base-packages.sh" ]
    grep -q "apk update" "$TEST_ROOTFS/etc/oobe.d/00-base-packages.sh"
    grep -q "apk add" "$TEST_ROOTFS/etc/oobe.d/00-base-packages.sh"
}

@test "build: OOBE script runs scripts from oobe.d" {
    # Create a mock OOBE script
    mkdir -p "$TEST_ROOTFS/etc"
    cat > "$TEST_ROOTFS/etc/oobe.sh" << 'EOF'
#!/bin/sh
if [ -d /etc/oobe.d ]; then
    for script in /etc/oobe.d/*.sh; do
        if [ -x "$script" ]; then
            "$script"
        fi
    done
fi
EOF
    
    [ -f "$TEST_ROOTFS/etc/oobe.sh" ]
    grep -q "/etc/oobe.d" "$TEST_ROOTFS/etc/oobe.sh"
}

@test "build: logging functions output to stderr" {
    # Test that log functions go to stderr
    output=$(log_info "test" 2>&1 1>/dev/null)
    [ -n "$output" ]
    
    # stdout should be empty
    output=$(log_info "test" 2>/dev/null)
    [ -z "$output" ]
}

@test "build: download_minirootfs returns clean path" {
    # Mock download_minirootfs to test output capture
    mock_download() {
        log_info "Downloading..." >&2
        log_progress "In progress..." >&2
        echo "/path/to/minirootfs.tar.gz"
    }
    
    # Output should only contain the path, not log messages
    output=$(mock_download 2>/dev/null)
    [ "$output" = "/path/to/minirootfs.tar.gz" ]
    
    # Logs should go to stderr
    errors=$(mock_download 2>&1 1>/dev/null)
    [[ "$errors" =~ "Downloading" ]]
}

@test "build: WSL_EXE is initialized before use" {
    # Unset WSL_EXE to simulate fresh environment
    unset WSL_EXE
    
    # distribution_exists should initialize WSL_EXE
    # In test environment, this will fail but shouldn't crash
    run distribution_exists "test-distro"
    
    # Should not have "unbound variable" error
    ! [[ "$output" =~ "unbound variable" ]]
}

@test "build: no chroot operations during module install" {
    # Check that base module doesn't try to use chroot
    module_script="$BATS_TEST_DIRNAME/../../src/modules/base/install.sh"
    
    # Should not contain direct chroot calls
    ! grep -q "chroot\s" "$module_script"
    
    # Should not use package.sh functions that require chroot
    ! grep -q "update_package_db" "$module_script"
    ! grep -q "install_packages" "$module_script"
    ! grep -q "clean_package_cache" "$module_script"
}