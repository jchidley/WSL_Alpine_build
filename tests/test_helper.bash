#!/usr/bin/env bash
# Test helper functions for BATS tests

# Load bats helpers if available
if [[ -d "/usr/lib/bats/bats-support" ]]; then
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
fi

# Project root directory
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test directories
export TEST_DIR="${PROJECT_ROOT}/tests"
export FIXTURES_DIR="${TEST_DIR}/fixtures"
export MOCKS_DIR="${TEST_DIR}/mocks"
export SRC_DIR="$PROJECT_ROOT/src"
export LIB_DIR="$SRC_DIR/lib"

# Temporary test directory
export TEST_TEMP_DIR=""

# Load project libraries
load_lib() {
    local lib_name="$1"
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/src/lib/${lib_name}.sh"
}

# Setup function - called before each test
setup() {
    # Create temporary directory for test
    TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/alpine-wsl-test.XXXXXX")
    export TEST_TEMP_DIR
    
    # Set test environment variables
    export DEBUG="${BATS_DEBUG:-0}"
    export VERBOSE="${BATS_VERBOSE:-0}"
    export DRY_RUN=0
    export LOG_FILE="${TEST_TEMP_DIR}/test.log"
    
    # Mock WSL executable
    export WSL_EXE="${MOCKS_DIR}/wsl.exe"
    
    # Create mock wsl.exe if needed
    if [[ ! -f "$WSL_EXE" ]]; then
        mkdir -p "$MOCKS_DIR"
        create_mock_wsl
    fi
}

# Teardown function - called after each test
teardown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create mock wsl.exe
create_mock_wsl() {
    cat > "$WSL_EXE" << 'EOF'
#!/bin/bash
# Mock wsl.exe for testing

case "$1" in
    --list)
        if [[ "$2" == "--all" ]]; then
            # Output in UTF-16LE format simulation
            echo -e "Windows Subsystem for Linux Distributions:\nalp2\nDebian (Default)"
        elif [[ "$2" == "--quiet" ]]; then
            echo -e "alp2\nDebian"
        elif [[ "$2" == "--verbose" ]]; then
            echo -e "  NAME      STATE           VERSION"
            echo -e "* Debian    Running         2"
            echo -e "  alp2      Stopped         2"
        fi
        ;;
    --import)
        echo "Importing distribution: $2"
        exit 0
        ;;
    --export)
        echo "Exporting distribution: $2"
        exit 0
        ;;
    --unregister)
        echo "Unregistering distribution: $2"
        exit 0
        ;;
    --terminate)
        echo "Terminating distribution: $2"
        exit 0
        ;;
    --set-version)
        echo "Setting WSL version for $2 to $3"
        exit 0
        ;;
    -d)
        shift
        local distro="$1"
        shift
        echo "Running in distribution: $distro"
        # Execute the command if provided
        if [[ $# -gt 0 ]]; then
            "$@"
        fi
        ;;
    --version)
        echo "WSL version: 2.0.0.0"
        ;;
    --help)
        echo "Windows Subsystem for Linux"
        echo "Usage: wsl.exe [options]"
        echo "--vhd is supported"
        ;;
    *)
        echo "Mock wsl.exe: Unknown command $1" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$WSL_EXE"
}

# Create a test rootfs directory
create_test_rootfs() {
    local rootfs_dir="${1:-$TEST_TEMP_DIR/rootfs}"
    
    mkdir -p "$rootfs_dir"/{etc,bin,sbin,usr,var,lib,home,root,tmp,proc,sys,dev}
    mkdir -p "$rootfs_dir"/etc/apk
    mkdir -p "$rootfs_dir"/var/cache/apk
    
    # Create basic files
    touch "$rootfs_dir"/etc/passwd
    touch "$rootfs_dir"/etc/group
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main" > "$rootfs_dir"/etc/apk/repositories
    
    # Create mock apk binary
    cat > "$rootfs_dir"/sbin/apk << 'EOF'
#!/bin/sh
echo "Mock APK: $*"
exit 0
EOF
    chmod +x "$rootfs_dir"/sbin/apk
    
    echo "$rootfs_dir"
}

# Create a test minirootfs archive
create_test_minirootfs() {
    local output_file="${1:-$TEST_TEMP_DIR/test-minirootfs.tar.gz}"
    local temp_root="${TEST_TEMP_DIR}/minirootfs"
    
    create_test_rootfs "$temp_root"
    
    # Create archive
    (cd "$temp_root" && tar -czf "$output_file" .)
    
    # Create checksum
    (cd "$(dirname "$output_file")" && sha256sum "$(basename "$output_file")" > "${output_file}.sha256")
    
    echo "$output_file"
}

# Mock wget for testing downloads
mock_wget() {
    local mock_dir="${TEST_TEMP_DIR}/mocks"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/wget" << 'EOF'
#!/bin/bash
# Mock wget for testing

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O)
            output_file="$2"
            shift 2
            ;;
        -q|--quiet|--show-progress)
            shift
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done

# Handle different URLs
case "$url" in
    *minirootfs*.tar.gz)
        # Create a fake minirootfs
        echo "Fake minirootfs content" > "${output_file:-minirootfs.tar.gz}"
        ;;
    *.sha256)
        # Create a fake checksum
        echo "d2ca1ac8e2c2e5b0e6322a911c7f38e6bbf601fa294d9c1193ce6875e4a7d8e3  alpine-minirootfs-3.18.6-x86_64.tar.gz" > "${output_file:-checksum.sha256}"
        ;;
    *)
        echo "Mock wget: $url"
        ;;
esac
exit 0
EOF
    chmod +x "$mock_dir/wget"
    export PATH="$mock_dir:$PATH"
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file" >&2
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Directory does not exist: $dir" >&2
        return 1
    fi
}

# Assert file contains
assert_file_contains() {
    local file="$1"
    local content="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file" >&2
        return 1
    fi
    
    if ! grep -q "$content" "$file"; then
        echo "File $file does not contain: $content" >&2
        echo "File contents:" >&2
        cat "$file" >&2
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    if [[ ${status:-1} -ne 0 ]]; then
        echo "Command failed with status ${status:-1}" >&2
        echo "Output: ${output:-}" >&2
        return 1
    fi
}

# Assert command fails
assert_failure() {
    if [[ ${status:-0} -eq 0 ]]; then
        echo "Command succeeded but should have failed" >&2
        echo "Output: ${output:-}" >&2
        return 1
    fi
}

# Assert output contains
assert_output_contains() {
    local expected="$1"
    
    if [[ ! "${output:-}" =~ $expected ]]; then
        echo "Output does not contain: $expected" >&2
        echo "Actual output: ${output:-}" >&2
        return 1
    fi
}

# Assert output equals
assert_output_equals() {
    local expected="$1"
    
    if [[ "${output:-}" != "$expected" ]]; then
        echo "Output does not equal expected" >&2
        echo "Expected: $expected" >&2
        echo "Actual: ${output:-}" >&2
        return 1
    fi
}

# Run command and capture output
run_command() {
    run "$@"
    # BATS sets $status and $output automatically
}

# Skip test if not in WSL
skip_if_not_wsl() {
    if [[ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]] && ! command -v wsl.exe &>/dev/null; then
        skip "Not running in WSL environment"
    fi
}

# Skip test if in CI
skip_if_ci() {
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        skip "Test skipped in CI environment"
    fi
}

# Skip test if command not available
skip_if_missing_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        skip "Command not available: $cmd"
    fi
}

# Create mock chroot for testing package operations
mock_chroot() {
    local mock_dir="${TEST_TEMP_DIR}/mocks"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/chroot" << 'EOF'
#!/bin/bash
# Mock chroot for testing

# Get the root directory
root_dir="$1"
shift

# Get the command to run
if [[ "$1" == "/sbin/apk" ]]; then
    shift  # Remove /sbin/apk
    echo "Mock APK in chroot: $*"
    
    # Simulate different APK commands
    case "$1" in
        update)
            echo "fetch https://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64/APKINDEX.tar.gz"
            echo "fetch https://dl-cdn.alpinelinux.org/alpine/v3.18/community/x86_64/APKINDEX.tar.gz"
            ;;
        add)
            shift  # Remove 'add'
            echo "Installing packages: $*"
            ;;
        del)
            shift  # Remove 'del'
            echo "Removing packages: $*"
            ;;
        list)
            if [[ "$2" == "--installed" ]]; then
                echo "alpine-base-3.18.0-r0"
                echo "busybox-1.36.1-r0"
            fi
            ;;
        *)
            echo "Mock APK: Unknown command"
            ;;
    esac
    exit 0
else
    # Run the command normally
    "$@"
fi
EOF
    chmod +x "$mock_dir/chroot"
    export PATH="$mock_dir:$PATH"
}