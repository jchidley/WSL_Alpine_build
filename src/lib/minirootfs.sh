#!/usr/bin/env bash
# ABOUTME: Safe minirootfs operations for Alpine WSL build
# ABOUTME: Handles downloading, verifying, and extracting Alpine minirootfs

# Prevent multiple sourcing
[[ -n "${__MINIROOTFS_SH_LOADED:-}" ]] && return 0
__MINIROOTFS_SH_LOADED=1

# Common functions are sourced by main script

# Default configuration
export ALPINE_VERSION="${ALPINE_VERSION:-3.18.6}"
export ALPINE_ARCH="${ALPINE_ARCH:-x86_64}"
export ALPINE_MIRROR="${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
export CACHE_DIR="${CACHE_DIR:-$HOME/.cache/alpine-wsl}"

# Get minirootfs URL
get_minirootfs_url() {
    local version="${1:-$ALPINE_VERSION}"
    local arch="${2:-$ALPINE_ARCH}"
    local version_major="${version%.*}"
    
    echo "${ALPINE_MIRROR}/v${version_major}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz"
}

# Get checksum file URL
get_checksum_url() {
    local version="${1:-$ALPINE_VERSION}"
    local arch="${2:-$ALPINE_ARCH}"
    local version_major="${version%.*}"
    
    echo "${ALPINE_MIRROR}/v${version_major}/releases/${arch}/alpine-minirootfs-${version}-${arch}.tar.gz.sha256"
}

# Download file with caching
download_with_cache() {
    local url="$1"
    local output_file="$2"
    local cache_file="${CACHE_DIR}/$(basename "$url")"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"
    
    # Check if file exists in cache
    if [[ -f "$cache_file" ]]; then
        log_info "Using cached file: $(basename "$cache_file")"
        cp "$cache_file" "$output_file"
        return 0
    fi
    
    # Download file
    log_progress "Downloading: $(basename "$url")"
    if wget -q --show-progress -O "$output_file" "$url"; then
        # Cache the file
        cp "$output_file" "$cache_file"
        log_success "Downloaded successfully"
        return 0
    else
        log_error "Failed to download: $url"
        return 1
    fi
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local checksum_file="$2"
    
    log_progress "Verifying checksum..."
    
    if [[ ! -f "$checksum_file" ]]; then
        log_error "Checksum file not found: $checksum_file"
        return 1
    fi
    
    # Extract expected checksum
    local expected_checksum
    expected_checksum=$(awk '{print $1}' "$checksum_file")
    
    # Calculate actual checksum
    local actual_checksum
    actual_checksum=$(sha256sum "$file" | awk '{print $1}')
    
    if [[ "$expected_checksum" == "$actual_checksum" ]]; then
        log_success "Checksum verified"
        return 0
    else
        log_error "Checksum verification failed"
        log_error "Expected: $expected_checksum"
        log_error "Actual:   $actual_checksum"
        return 1
    fi
}

# Download Alpine minirootfs
download_minirootfs() {
    local version="${1:-$ALPINE_VERSION}"
    local arch="${2:-$ALPINE_ARCH}"
    local output_dir="${3:-.}"
    
    local minirootfs_url
    local checksum_url
    local minirootfs_file
    local checksum_file
    
    minirootfs_url=$(get_minirootfs_url "$version" "$arch")
    checksum_url=$(get_checksum_url "$version" "$arch")
    minirootfs_file="$output_dir/$(basename "$minirootfs_url")"
    checksum_file="$output_dir/$(basename "$checksum_url")"
    
    log_info "Downloading Alpine Linux minirootfs v${version} for ${arch}..."
    
    # Download minirootfs
    if ! download_with_cache "$minirootfs_url" "$minirootfs_file"; then
        return 1
    fi
    
    # Download checksum
    if ! download_with_cache "$checksum_url" "$checksum_file"; then
        return 1
    fi
    
    # Verify checksum
    if ! verify_checksum "$minirootfs_file" "$checksum_file"; then
        # Remove corrupted file from cache
        rm -f "${CACHE_DIR}/$(basename "$minirootfs_file")"
        return 1
    fi
    
    # Output the file path (important: must be last output)
    echo "$minirootfs_file"
}

# Extract minirootfs
extract_minirootfs() {
    local tarball="$1"
    local target_dir="$2"
    local preserve_ownership="${3:-false}"
    
    if [[ ! -f "$tarball" ]]; then
        log_error "Tarball not found: $tarball"
        return 1
    fi
    
    if [[ ! -d "$target_dir" ]]; then
        log_progress "Creating target directory: $target_dir"
        mkdir -p "$target_dir"
    fi
    
    log_progress "Extracting root filesystem..."
    
    # Count files for progress
    local file_count
    file_count=$(tar -tzf "$tarball" | wc -l)
    log_verbose "Extracting $file_count files..."
    
    # Extract based on preservation setting
    local tar_opts="-xzf"
    if [[ "$preserve_ownership" == "true" ]]; then
        tar_opts="--numeric-owner $tar_opts"
    fi
    
    if tar $tar_opts "$tarball" -C "$target_dir"; then
        log_success "Root filesystem extracted successfully"
        return 0
    else
        log_error "Failed to extract minirootfs"
        return 1
    fi
}

# Verify extracted filesystem
verify_extracted_fs() {
    local rootfs_dir="$1"
    
    log_progress "Verifying extracted filesystem..."
    
    # Check essential directories
    local essential_dirs=("etc" "bin" "sbin" "usr" "var" "lib")
    local missing_dirs=()
    
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$rootfs_dir/$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        log_success "Filesystem verification passed"
        return 0
    else
        log_error "Missing essential directories: ${missing_dirs[*]}"
        return 1
    fi
}

# Configure APK repositories
configure_apk_repos() {
    local rootfs_dir="$1"
    local version="${2:-$ALPINE_VERSION}"
    local mirror="${3:-$ALPINE_MIRROR}"
    
    local version_major="${version%.*}"
    local repos_file="$rootfs_dir/etc/apk/repositories"
    
    log_progress "Configuring APK repositories..."
    
    # Ensure directory exists
    mkdir -p "$(dirname "$repos_file")"
    
    # Write repository configuration
    cat > "$repos_file" << EOF
${mirror}/v${version_major}/main
${mirror}/v${version_major}/community
@testing ${mirror}/edge/testing
EOF
    
    log_success "APK repositories configured"
    log_verbose "Repository file: $repos_file"
}

# Clean up minirootfs for WSL
cleanup_for_wsl() {
    local rootfs_dir="$1"
    
    log_progress "Cleaning up filesystem for WSL..."
    
    # Remove resolv.conf to let WSL generate it
    rm -f "$rootfs_dir/etc/resolv.conf"
    
    # Create essential directories with proper permissions
    mkdir -p "$rootfs_dir"/{proc,sys,dev,tmp,run}
    chmod 1777 "$rootfs_dir/tmp"
    chmod 755 "$rootfs_dir/run"
    
    # Remove any existing machine-id to let systemd generate it
    rm -f "$rootfs_dir/etc/machine-id"
    
    # Clean APK cache
    rm -rf "$rootfs_dir/var/cache/apk"/*
    
    log_success "Filesystem cleaned up for WSL"
}

# List available Alpine versions
list_alpine_versions() {
    local arch="${1:-$ALPINE_ARCH}"
    
    log_info "Fetching available Alpine versions for $arch..."
    
    # Get list of version directories
    local versions=()
    local version_list
    
    version_list=$(wget -qO- "${ALPINE_MIRROR}/" | grep -oE 'v[0-9]+\.[0-9]+' | sort -V | uniq)
    
    for version_dir in $version_list; do
        # Check if minirootfs exists for this version
        local check_url="${ALPINE_MIRROR}/${version_dir}/releases/${arch}/"
        if wget -q --spider "$check_url" 2>/dev/null; then
            versions+=("${version_dir#v}")
        fi
    done
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        log_error "No Alpine versions found for architecture: $arch"
        return 1
    fi
    
    log_success "Available Alpine versions:"
    for version in "${versions[@]}"; do
        echo "  - $version"
    done
}

# Download and prepare minirootfs
prepare_minirootfs() {
    local version="${1:-$ALPINE_VERSION}"
    local arch="${2:-$ALPINE_ARCH}"
    local target_dir="${3:-./rootfs}"
    local work_dir="${4:-./work}"
    
    log_info "Preparing Alpine minirootfs v${version} for ${arch}..."
    
    # Create work directory
    mkdir -p "$work_dir"
    
    # Download minirootfs
    local minirootfs_file
    minirootfs_file=$(download_minirootfs "$version" "$arch" "$work_dir")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Extract minirootfs
    if ! extract_minirootfs "$minirootfs_file" "$target_dir"; then
        return 1
    fi
    
    # Verify extraction
    if ! verify_extracted_fs "$target_dir"; then
        return 1
    fi
    
    # Configure APK repositories
    if ! configure_apk_repos "$target_dir" "$version"; then
        return 1
    fi
    
    # Clean up for WSL
    if ! cleanup_for_wsl "$target_dir"; then
        return 1
    fi
    
    log_success "Minirootfs prepared successfully at: $target_dir"
    return 0
}

# Export functions
export -f get_minirootfs_url get_checksum_url download_with_cache
export -f verify_checksum download_minirootfs extract_minirootfs
export -f verify_extracted_fs configure_apk_repos cleanup_for_wsl
export -f list_alpine_versions prepare_minirootfs