#!/bin/bash
# Test helper functions for BATS tests

# Load bats helpers if available
if [[ -d "/usr/lib/bats/bats-support" ]]; then
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
fi

# Project root directory
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SRC_DIR="$PROJECT_ROOT/src"
export LIB_DIR="$SRC_DIR/lib"

# Disable output during tests unless debugging
if [[ "${BATS_DEBUG:-0}" != "1" ]]; then
    export VERBOSE=0
    export DEBUG=0
fi

# Mock wsl.exe for testing outside WSL
mock_wsl() {
    local mock_dir="${BATS_TEST_TMPDIR}/mocks"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/wsl.exe" << 'EOF'
#!/bin/bash
case "$1" in
    --list)
        echo "Ubuntu"
        echo "Debian"
        ;;
    --version)
        echo "WSL version: 2.0.0.0"
        ;;
    --import)
        echo "Mock import successful"
        exit 0
        ;;
    --unregister)
        echo "Mock unregister successful"
        exit 0
        ;;
    *)
        echo "Mock wsl.exe: $*" >&2
        exit 0
        ;;
esac
EOF
    chmod +x "$mock_dir/wsl.exe"
    export PATH="$mock_dir:$PATH"
}

# Create a temporary Alpine minirootfs for testing
create_test_rootfs() {
    local test_dir="$1"
    mkdir -p "$test_dir"/{etc,bin,lib,dev,proc,sys,tmp}
    
    # Create basic files
    echo "Alpine Linux Test" > "$test_dir/etc/alpine-release"
    echo "#!/bin/sh" > "$test_dir/bin/sh"
    chmod +x "$test_dir/bin/sh"
    
    # Create test tarball
    tar -czf "$test_dir.tar.gz" -C "$test_dir" .
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file" >&2
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir" >&2
        return 1
    fi
}