#!/usr/bin/env bats
# Unit tests for package.sh library

load ../test_helper

@test "package: library can be sourced" {
    run_command load_lib package
    assert_success
}

@test "package: run_apk_in_rootfs validates rootfs" {
    load_lib package
    
    # Test with non-existent rootfs
    run_command run_apk_in_rootfs "/tmp/nonexistent" update
    assert_failure
    assert_output_contains "Root filesystem not found"
}

@test "package: run_apk_in_rootfs executes APK commands" {
    load_lib package
    
    # Create test rootfs with mock APK
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Run APK command
    run_command run_apk_in_rootfs "$rootfs_dir" update
    assert_success
    assert_output_contains "Mock APK in chroot: update"
}

@test "package: update_package_db updates APK database" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Update package DB
    run_command update_package_db "$rootfs_dir"
    assert_success
    assert_output_contains "Package database updated"
    assert_output_contains "fetch https://dl-cdn.alpinelinux.org"
}

@test "package: install_packages installs packages" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Install packages
    run_command install_packages "$rootfs_dir" bash git curl
    assert_success
    assert_output_contains "Installing packages: --no-cache bash git curl"
    assert_output_contains "Packages installed successfully"
}

@test "package: install_packages handles empty package list" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Install no packages
    run_command install_packages "$rootfs_dir"
    assert_success
    assert_output_contains "No packages specified"
}

@test "package: remove_packages removes packages" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Remove packages
    run_command remove_packages "$rootfs_dir" vim nano
    assert_success
    assert_output_contains "Removing packages: vim nano"
    assert_output_contains "Packages removed successfully"
}

@test "package: search_packages searches for packages" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Search packages
    run_command search_packages "$rootfs_dir" "docker"
    assert_success
    assert_output_contains "Mock APK in chroot: search -v docker"
}

@test "package: list_installed_packages lists packages" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # List packages
    run_command list_installed_packages "$rootfs_dir"
    assert_success
    assert_output_contains "alpine-base-3.18.0-r0"
    assert_output_contains "busybox-1.36.1-r0"
}

@test "package: list_installed_packages saves to file" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # List packages to file
    local output_file="$TEST_TEMP_DIR/packages.txt"
    run_command list_installed_packages "$rootfs_dir" "$output_file"
    assert_success
    assert_output_contains "Package list saved to"
    assert_file_exists "$output_file"
}

@test "package: install_package_group installs base group" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Install base group
    run_command install_package_group "$rootfs_dir" "base"
    assert_success
    assert_output_contains "alpine-base"
    assert_output_contains "openrc"
    assert_output_contains "sudo"
}

@test "package: install_package_group installs development group" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Install development group
    run_command install_package_group "$rootfs_dir" "development"
    assert_success
    assert_output_contains "git"
    assert_output_contains "curl"
    assert_output_contains "build-base"
}

@test "package: install_package_group handles unknown group" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Install unknown group
    run_command install_package_group "$rootfs_dir" "unknown"
    assert_failure
    assert_output_contains "Unknown package group"
    assert_output_contains "Available groups"
}

@test "package: clean_package_cache cleans cache" {
    load_lib package
    
    # Create test rootfs with cache
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    mkdir -p "$rootfs_dir/var/cache/apk"
    touch "$rootfs_dir/var/cache/apk/test1"
    touch "$rootfs_dir/var/cache/apk/test2"
    
    # Mock chroot
    mock_chroot
    
    # Clean cache
    run_command clean_package_cache "$rootfs_dir"
    assert_success
    assert_output_contains "Package cache cleaned"
    
    # Cache should be empty
    [[ -z "$(ls -A "$rootfs_dir/var/cache/apk" 2>/dev/null)" ]]
}

@test "package: fix_package_db fixes database" {
    load_lib package
    
    # Create test rootfs without proper directories
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir"
    
    # Mock chroot
    mock_chroot
    
    # Fix package DB
    run_command fix_package_db "$rootfs_dir"
    assert_success
    assert_output_contains "Package database fixed"
    
    # Directories should exist
    assert_dir_exists "$rootfs_dir/var/cache/apk"
    assert_dir_exists "$rootfs_dir/etc/apk"
}

@test "package: install_from_file installs from package list" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Create package file
    local pkg_file="$TEST_TEMP_DIR/packages.txt"
    cat > "$pkg_file" << EOF
# Comment line
bash
git

curl
# Another comment
vim
EOF
    
    # Install from file
    run_command install_from_file "$rootfs_dir" "$pkg_file"
    assert_success
    assert_output_contains "bash git curl vim"
}

@test "package: create_package_script creates installation script" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir="$TEST_TEMP_DIR/rootfs"
    mkdir -p "$rootfs_dir"
    
    # Create script
    local script_path="$rootfs_dir/install-packages.sh"
    run_command create_package_script "$rootfs_dir" "$script_path" bash git curl
    assert_success
    assert_output_contains "Package script created"
    
    # Verify script
    assert_file_exists "$script_path"
    assert_file_contains "$script_path" "apk update"
    assert_file_contains "$script_path" "bash"
    assert_file_contains "$script_path" "git"
    assert_file_contains "$script_path" "curl"
    
    # Script should be executable
    [[ -x "$script_path" ]]
}

@test "package: get_package_info shows package information" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Get package info
    run_command get_package_info "$rootfs_dir" "bash"
    assert_success
    assert_output_contains "Mock APK in chroot: info -a bash"
}

@test "package: is_package_installed checks installation status" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot to simulate installed package
    local mock_dir="${TEST_TEMP_DIR}/mocks"
    mkdir -p "$mock_dir"
    cat > "$mock_dir/chroot" << 'EOF'
#!/bin/bash
root_dir="$1"
shift
if [[ "$1" == "/sbin/apk" ]] && [[ "$2" == "info" ]] && [[ "$3" == "--installed" ]]; then
    if [[ "$4" == "bash" ]]; then
        echo "bash-5.2.15-r0"
        exit 0
    else
        exit 1
    fi
fi
"$@"
EOF
    chmod +x "$mock_dir/chroot"
    export PATH="$mock_dir:$PATH"
    
    # Test installed package
    run_command is_package_installed "$rootfs_dir" "bash"
    assert_success
    
    # Test non-installed package
    run_command is_package_installed "$rootfs_dir" "nonexistent"
    assert_failure
}

@test "package: upgrade_packages upgrades all packages" {
    load_lib package
    
    # Create test rootfs
    local rootfs_dir
    rootfs_dir=$(create_test_rootfs)
    
    # Mock chroot
    mock_chroot
    
    # Upgrade packages
    run_command upgrade_packages "$rootfs_dir"
    assert_success
    assert_output_contains "Upgrading all packages"
    assert_output_contains "Mock APK in chroot: update"
    assert_output_contains "Mock APK in chroot: upgrade --available"
    assert_output_contains "Packages upgraded successfully"
}