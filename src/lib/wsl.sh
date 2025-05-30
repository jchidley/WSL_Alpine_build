#!/usr/bin/env bash
# ABOUTME: WSL-specific operations for Alpine WSL build
# ABOUTME: Handles WSL configuration, import/export, and management

# Prevent multiple sourcing
[[ -n "${__WSL_SH_LOADED:-}" ]] && return 0
__WSL_SH_LOADED=1

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "${SCRIPT_DIR}/common.sh"

# WSL configuration template
create_wsl_conf() {
    local rootfs_dir="$1"
    local default_user="${2:-wsluser}"
    local systemd_enabled="${3:-false}"
    
    log_progress "Creating WSL configuration..."
    
    # Ensure directory exists
    mkdir -p "$rootfs_dir/etc"
    
    # Create wsl.conf
    cat > "$rootfs_dir/etc/wsl.conf" << EOF
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true
root = /mnt/

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[boot]
systemd = ${systemd_enabled}
EOF
    
    # Add boot command if systemd is disabled
    if [[ "$systemd_enabled" == "false" ]]; then
        cat >> "$rootfs_dir/etc/wsl.conf" << 'EOF'
command = /sbin/openrc default
EOF
    fi
    
    # Add default user if specified
    if [[ -n "$default_user" ]]; then
        cat >> "$rootfs_dir/etc/wsl.conf" << EOF

[user]
default = ${default_user}
EOF
    fi
    
    log_success "WSL configuration created"
}

# Create WSL distribution configuration
create_wsl_distribution_conf() {
    local rootfs_dir="$1"
    local distro_name="${2:-alpine-wsl}"
    
    log_progress "Creating WSL distribution configuration..."
    
    cat > "$rootfs_dir/etc/wsl-distribution.conf" << EOF
[oobe]
default = ${distro_name}
command = /etc/oobe.sh
EOF
    
    log_success "WSL distribution configuration created"
}

# Import distribution to WSL
import_distribution() {
    local distro_name="$1"
    local tar_path="$2"
    local install_location="${3:-}"
    local wsl_version="${4:-2}"
    
    log_progress "Importing distribution to WSL..."
    
    # Validate inputs
    if ! validate_distribution_name "$distro_name"; then
        return 1
    fi
    
    if [[ ! -f "$tar_path" ]]; then
        log_error "Archive file not found: $tar_path"
        return 1
    fi
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Check if distribution already exists
    if distribution_exists "$distro_name"; then
        log_warning "Distribution '$distro_name' already exists"
        return 1
    fi
    
    # Determine install location
    if [[ -z "$install_location" ]]; then
        install_location=$(create_wsl_install_dir "$distro_name")
    fi
    
    # Convert paths to Windows format
    local win_install_location
    local win_tar_path
    win_install_location=$(get_windows_path "$install_location")
    win_tar_path=$(get_windows_path "$tar_path")
    
    log_info "Import details:"
    log_info "  Name: $distro_name"
    log_info "  Location: $win_install_location"
    log_info "  Archive: $win_tar_path"
    log_info "  Version: WSL${wsl_version}"
    
    # Perform import
    if dry_run_exec $WSL_EXE --import "$distro_name" "$win_install_location" "$win_tar_path" --version "$wsl_version"; then
        log_success "Distribution imported successfully"
        return 0
    else
        log_error "Failed to import distribution"
        return 1
    fi
}

# Export distribution from WSL
export_distribution() {
    local distro_name="$1"
    local output_file="$2"
    local vhd_format="${3:-false}"
    
    log_progress "Exporting distribution from WSL..."
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Check if distribution exists
    if ! distribution_exists "$distro_name"; then
        log_error "Distribution '$distro_name' not found"
        return 1
    fi
    
    # Determine export format and options
    local export_opts=""
    if [[ "$vhd_format" == "true" ]] && wsl_supports_vhd; then
        export_opts="--vhd"
        output_file="${output_file%.tar*}.vhdx"
    fi
    
    # Convert output path to Windows format
    local win_output_file
    win_output_file=$(get_windows_path "$output_file")
    
    log_info "Exporting '$distro_name' to: $output_file"
    
    # Perform export
    if dry_run_exec $WSL_EXE --export "$distro_name" "$win_output_file" $export_opts; then
        log_success "Distribution exported successfully"
        return 0
    else
        log_error "Failed to export distribution"
        return 1
    fi
}

# Unregister distribution from WSL
unregister_distribution() {
    local distro_name="$1"
    local preserve_data="${2:-false}"
    
    log_progress "Unregistering WSL distribution: $distro_name"
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Check if distribution exists
    if ! distribution_exists "$distro_name"; then
        log_warning "Distribution '$distro_name' not found"
        return 1
    fi
    
    # Export data if preserve flag is set
    if [[ "$preserve_data" == "true" ]]; then
        local backup_file="${distro_name}-backup-$(date +%Y%m%d-%H%M%S).tar"
        log_info "Preserving distribution data to: $backup_file"
        if ! export_distribution "$distro_name" "$backup_file"; then
            log_error "Failed to backup distribution data"
            return 1
        fi
    fi
    
    # Terminate any running instances
    log_verbose "Terminating any running instances..."
    $WSL_EXE --terminate "$distro_name" 2>/dev/null || true
    
    # Unregister the distribution
    if dry_run_exec $WSL_EXE --unregister "$distro_name"; then
        log_success "Distribution unregistered successfully"
        
        # Clean up installation directories
        cleanup_wsl_install_dirs "$distro_name"
        
        return 0
    else
        log_error "Failed to unregister distribution"
        return 1
    fi
}

# Clean up WSL installation directories
cleanup_wsl_install_dirs() {
    local distro_name="$1"
    
    log_progress "Cleaning up WSL installation directories..."
    
    # Get real home directory
    local real_home
    real_home=$(get_real_home)
    
    # Get Windows username
    local windows_user
    windows_user=$(get_windows_username)
    
    # Potential installation directories
    local install_dirs=(
        "$real_home/.wsl/$distro_name"
        "/mnt/c/Users/$windows_user/WSL/$distro_name"
        "/mnt/c/WSL/$distro_name"
    )
    
    for dir in "${install_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_verbose "Removing directory: $dir"
            safe_remove_dir "$dir" "WSL installation directory"
        fi
    done
}

# Check if WSL supports VHD export
wsl_supports_vhd() {
    # VHD export is supported in newer versions of WSL
    # This is a simple check - could be enhanced
    if $WSL_EXE --help 2>/dev/null | grep -q -- "--vhd"; then
        return 0
    else
        return 1
    fi
}

# Get WSL version of a distribution
get_wsl_version() {
    local distro_name="$1"
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Get distribution info
    local wsl_info
    wsl_info=$($WSL_EXE --list --verbose 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | grep -E "^\s*${distro_name}\s")
    
    if [[ -n "$wsl_info" ]]; then
        # Extract version (typically in the 3rd column)
        local version
        version=$(echo "$wsl_info" | awk '{print $3}')
        if [[ "$version" =~ ^[12]$ ]]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Default to 2 if we can't determine
    echo "2"
}

# Convert WSL distribution to different version
convert_wsl_version() {
    local distro_name="$1"
    local target_version="$2"
    
    if [[ ! "$target_version" =~ ^[12]$ ]]; then
        log_error "Invalid WSL version: $target_version (must be 1 or 2)"
        return 1
    fi
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Check current version
    local current_version
    current_version=$(get_wsl_version "$distro_name")
    
    if [[ "$current_version" == "$target_version" ]]; then
        log_info "Distribution is already WSL version $target_version"
        return 0
    fi
    
    log_progress "Converting $distro_name from WSL$current_version to WSL$target_version..."
    
    # Terminate any running instances
    $WSL_EXE --terminate "$distro_name" 2>/dev/null || true
    
    # Perform conversion
    if dry_run_exec $WSL_EXE --set-version "$distro_name" "$target_version"; then
        log_success "Distribution converted to WSL$target_version"
        return 0
    else
        log_error "Failed to convert distribution"
        return 1
    fi
}

# List all WSL distributions with details
list_distributions_detailed() {
    log_info "WSL Distributions:"
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Get detailed list
    local wsl_output
    wsl_output=$($WSL_EXE --list --verbose 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null)
    
    # Parse and display
    echo "$wsl_output" | while IFS= read -r line; do
        # Skip header and empty lines
        if [[ "$line" =~ ^[[:space:]]*NAME || -z "$line" ]]; then
            continue
        fi
        
        # Extract fields
        local name state version
        name=$(echo "$line" | awk '{print $1}' | tr -d '*')
        state=$(echo "$line" | awk '{print $2}')
        version=$(echo "$line" | awk '{print $3}')
        
        if [[ -n "$name" ]]; then
            printf "  %-20s State: %-10s Version: WSL%s\n" "$name" "$state" "$version"
        fi
    done
}

# Run command in WSL distribution
run_in_distribution() {
    local distro_name="$1"
    shift
    local command="$*"
    
    # Find WSL executable
    if ! find_wsl_exe; then
        return 1
    fi
    
    # Check if distribution exists
    if ! distribution_exists "$distro_name"; then
        log_error "Distribution '$distro_name' not found"
        return 1
    fi
    
    log_debug "Running in $distro_name: $command"
    
    # Execute command
    if dry_run_exec $WSL_EXE -d "$distro_name" -- "$@"; then
        return 0
    else
        return 1
    fi
}

# Package rootfs for WSL import
package_rootfs() {
    local rootfs_dir="$1"
    local output_file="$2"
    local compression="${3:---fast}"
    
    log_progress "Packaging root filesystem for WSL..."
    
    if [[ ! -d "$rootfs_dir" ]]; then
        log_error "Root filesystem directory not found: $rootfs_dir"
        return 1
    fi
    
    # Create temporary script for fakeroot
    local temp_script
    temp_script=$(mktemp /tmp/wsl-package.XXXXXX.sh)
    
    cat > "$temp_script" << EOF
#!/bin/bash
set -e
cd "$rootfs_dir"
tar --numeric-owner -c . | gzip $compression > "$output_file"
EOF
    
    chmod +x "$temp_script"
    
    # Run packaging under fakeroot to preserve ownership
    if command_exists fakeroot; then
        log_verbose "Packaging with fakeroot to preserve ownership"
        if fakeroot -- "$temp_script"; then
            rm -f "$temp_script"
            log_success "Root filesystem packaged successfully"
            
            # Verify the package
            local file_count
            file_count=$(tar -tzf "$output_file" 2>/dev/null | wc -l)
            log_info "Package contains $file_count files"
            
            return 0
        else
            rm -f "$temp_script"
            log_error "Failed to package root filesystem"
            return 1
        fi
    else
        log_warning "fakeroot not found, packaging without ownership preservation"
        if bash "$temp_script"; then
            rm -f "$temp_script"
            log_success "Root filesystem packaged (without ownership preservation)"
            return 0
        else
            rm -f "$temp_script"
            log_error "Failed to package root filesystem"
            return 1
        fi
    fi
}

# Create .wsl file for double-click install
create_wsl_file() {
    local tar_file="$1"
    local wsl_file="${2:-${tar_file%.tar.gz}.wsl}"
    
    if [[ ! -f "$tar_file" ]]; then
        log_error "TAR file not found: $tar_file"
        return 1
    fi
    
    log_progress "Creating .wsl file for easy installation..."
    
    # Simply copy the tar.gz to .wsl
    if cp "$tar_file" "$wsl_file"; then
        log_success "Created WSL file: $wsl_file"
        return 0
    else
        log_error "Failed to create WSL file"
        return 1
    fi
}

# Export functions
export -f create_wsl_conf create_wsl_distribution_conf
export -f import_distribution export_distribution unregister_distribution
export -f cleanup_wsl_install_dirs wsl_supports_vhd
export -f get_wsl_version convert_wsl_version
export -f list_distributions_detailed run_in_distribution
export -f package_rootfs create_wsl_file