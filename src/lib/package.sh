#!/usr/bin/env bash
# ABOUTME: Alpine package management operations
# ABOUTME: Handles APK package installation and management in rootfs

# Prevent multiple sourcing
[[ -n "${__PACKAGE_SH_LOADED:-}" ]] && return 0
__PACKAGE_SH_LOADED=1

# Common functions are sourced by main script

# Run APK command in rootfs
run_apk_in_rootfs() {
    local rootfs_dir="$1"
    shift
    local apk_args=("$@")
    
    if [[ ! -d "$rootfs_dir" ]]; then
        log_error "Root filesystem not found: $rootfs_dir"
        return 1
    fi
    
    # Check if we're in fakeroot environment
    if [[ -n "${FAKEROOTKEY:-}" ]]; then
        # We're already in fakeroot, can use chroot directly
        log_debug "Running APK via chroot (in fakeroot): apk ${apk_args[*]}"
        if dry_run_exec chroot "$rootfs_dir" /sbin/apk "${apk_args[@]}"; then
            return 0
        else
            return 1
        fi
    elif command_exists fakeroot && [[ -x "$rootfs_dir/sbin/apk" ]]; then
        # Need to run under fakeroot
        log_debug "Running APK via fakeroot chroot: apk ${apk_args[*]}"
        if dry_run_exec fakeroot -- chroot "$rootfs_dir" /sbin/apk "${apk_args[@]}"; then
            return 0
        else
            return 1
        fi
    else
        log_error "Cannot run APK - fakeroot/chroot not available or APK not found in rootfs"
        return 1
    fi
}

# Update APK package database
update_package_db() {
    local rootfs_dir="$1"
    local quiet="${2:-false}"
    
    log_progress "Updating package database..."
    
    local apk_opts=""
    if [[ "$quiet" == "true" ]]; then
        apk_opts="--quiet"
    fi
    
    if run_apk_in_rootfs "$rootfs_dir" update $apk_opts; then
        log_success "Package database updated"
        return 0
    else
        log_error "Failed to update package database"
        return 1
    fi
}

# Install packages in rootfs
install_packages() {
    local rootfs_dir="$1"
    shift
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages specified for installation"
        return 0
    fi
    
    log_progress "Installing packages: ${packages[*]}"
    
    if run_apk_in_rootfs "$rootfs_dir" add --no-cache "${packages[@]}"; then
        log_success "Packages installed successfully"
        return 0
    else
        log_error "Failed to install packages"
        return 1
    fi
}

# Remove packages from rootfs
remove_packages() {
    local rootfs_dir="$1"
    shift
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages specified for removal"
        return 0
    fi
    
    log_progress "Removing packages: ${packages[*]}"
    
    if run_apk_in_rootfs "$rootfs_dir" del "${packages[@]}"; then
        log_success "Packages removed successfully"
        return 0
    else
        log_error "Failed to remove packages"
        return 1
    fi
}

# Search for packages
search_packages() {
    local rootfs_dir="$1"
    local search_term="$2"
    
    log_progress "Searching for packages matching: $search_term"
    
    if run_apk_in_rootfs "$rootfs_dir" search -v "$search_term"; then
        return 0
    else
        log_error "Package search failed"
        return 1
    fi
}

# List installed packages
list_installed_packages() {
    local rootfs_dir="$1"
    local output_file="${2:-}"
    
    log_progress "Listing installed packages..."
    
    if [[ -n "$output_file" ]]; then
        if run_apk_in_rootfs "$rootfs_dir" list --installed > "$output_file"; then
            log_success "Package list saved to: $output_file"
            return 0
        else
            log_error "Failed to save package list"
            return 1
        fi
    else
        if run_apk_in_rootfs "$rootfs_dir" list --installed; then
            return 0
        else
            log_error "Failed to list packages"
            return 1
        fi
    fi
}

# Install package groups
install_package_group() {
    local rootfs_dir="$1"
    local group_name="$2"
    
    case "$group_name" in
        "base")
            install_packages "$rootfs_dir" \
                alpine-base \
                openrc \
                util-linux \
                sudo \
                bash \
                shadow \
                e2fsprogs \
                e2fsprogs-extra
            ;;
        
        "development")
            install_packages "$rootfs_dir" \
                git \
                curl \
                wget \
                openssh-client \
                build-base \
                python3 \
                nodejs \
                npm
            ;;
        
        "editors")
            install_packages "$rootfs_dir" \
                helix \
                vim \
                nano
            ;;
        
        "modern-cli")
            install_packages "$rootfs_dir" \
                fd \
                bat \
                zoxide \
                fzf \
                ripgrep \
                tree \
                htop \
                ncdu
            ;;
        
        "podman")
            install_packages "$rootfs_dir" \
                podman \
                podman-remote \
                fuse-overlayfs \
                slirp4netns \
                conmon \
                crun
            ;;
        
        "network")
            install_packages "$rootfs_dir" \
                openssh \
                curl \
                wget \
                bind-tools \
                net-tools \
                iputils
            ;;
        
        *)
            log_error "Unknown package group: $group_name"
            log_info "Available groups: base, development, editors, modern-cli, podman, network"
            return 1
            ;;
    esac
}

# Clean APK cache
clean_package_cache() {
    local rootfs_dir="$1"
    
    log_progress "Cleaning package cache..."
    
    # Clean APK cache
    if run_apk_in_rootfs "$rootfs_dir" cache clean; then
        log_verbose "APK cache cleaned"
    fi
    
    # Remove cache directory contents
    if [[ -d "$rootfs_dir/var/cache/apk" ]]; then
        rm -rf "$rootfs_dir/var/cache/apk"/*
        log_success "Package cache cleaned"
    fi
    
    return 0
}

# Fix package database
fix_package_db() {
    local rootfs_dir="$1"
    
    log_progress "Fixing package database..."
    
    # Ensure APK directories exist
    mkdir -p "$rootfs_dir/var/cache/apk"
    mkdir -p "$rootfs_dir/etc/apk"
    
    # Fix permissions
    chmod 755 "$rootfs_dir/var/cache/apk"
    chmod 755 "$rootfs_dir/etc/apk"
    
    # Update database
    if update_package_db "$rootfs_dir" true; then
        log_success "Package database fixed"
        return 0
    else
        log_error "Failed to fix package database"
        return 1
    fi
}

# Install packages from file
install_from_file() {
    local rootfs_dir="$1"
    local package_file="$2"
    
    if [[ ! -f "$package_file" ]]; then
        log_error "Package file not found: $package_file"
        return 1
    fi
    
    log_progress "Installing packages from: $package_file"
    
    # Read packages from file (skip comments and empty lines)
    local packages=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        packages+=("$line")
    done < "$package_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages found in file"
        return 0
    fi
    
    # Install packages
    install_packages "$rootfs_dir" "${packages[@]}"
}

# Create package installation script
create_package_script() {
    local rootfs_dir="$1"
    local script_path="$2"
    local packages=("${@:3}")
    
    log_progress "Creating package installation script..."
    
    cat > "$script_path" << 'EOF'
#!/bin/sh
# Alpine package installation script
set -e

echo "Installing packages..."
apk update

# Install packages
apk add --no-cache \
EOF
    
    # Add packages to script
    for pkg in "${packages[@]}"; do
        echo "    $pkg \\" >> "$script_path"
    done
    
    # Remove trailing backslash
    sed -i '$ s/ \\$//' "$script_path"
    
    # Add cleanup
    cat >> "$script_path" << 'EOF'

echo "Cleaning up..."
rm -rf /var/cache/apk/*

echo "Package installation complete!"
EOF
    
    chmod +x "$script_path"
    log_success "Package script created: $script_path"
}

# Get package info
get_package_info() {
    local rootfs_dir="$1"
    local package="$2"
    
    log_progress "Getting info for package: $package"
    
    if run_apk_in_rootfs "$rootfs_dir" info -a "$package"; then
        return 0
    else
        log_error "Failed to get package info"
        return 1
    fi
}

# Check if package is installed
is_package_installed() {
    local rootfs_dir="$1"
    local package="$2"
    
    if run_apk_in_rootfs "$rootfs_dir" info --installed "$package" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Upgrade all packages
upgrade_packages() {
    local rootfs_dir="$1"
    
    log_progress "Upgrading all packages..."
    
    # Update package database first
    if ! update_package_db "$rootfs_dir" true; then
        return 1
    fi
    
    # Upgrade packages
    if run_apk_in_rootfs "$rootfs_dir" upgrade --available; then
        log_success "Packages upgraded successfully"
        return 0
    else
        log_error "Failed to upgrade packages"
        return 1
    fi
}

# Export functions
export -f run_apk_in_rootfs update_package_db install_packages remove_packages
export -f search_packages list_installed_packages install_package_group
export -f clean_package_cache fix_package_db install_from_file
export -f create_package_script get_package_info is_package_installed
export -f upgrade_packages