#!/usr/bin/env bash
# Common functions for WSL Alpine build scripts

# Constants
DEFAULT_DISTRIBUTION_NAME="alp2"
TEST_DISTRIBUTION_PREFIX="alp-test-"
TEST_DISTRIBUTION_PATTERN="${TEST_DISTRIBUTION_PREFIX}[0-9]+"

# Logging functions
log_info() {
  echo "ℹ️  $*"
}

log_success() {
  echo "✅ $*"
}

log_error() {
  echo "❌ $*" >&2
}

log_warning() {
  echo "⚠️  $*"
}

log_progress() {
  echo "🔄 $*"
}

# Configuration loading function
load_config() {
  local env_file="${1:-.env}"
  
  if [ ! -f "$env_file" ]; then
    log_warning "No $env_file file found"
    return 1
  fi
  
  # Source the .env file
  set -a
  source "$env_file"
  set +a
  
  # Set defaults for critical variables
  SUDO="${SUDO:-sudo}"
  WSL_DISTRIBUTION_NAME="${WSL_DISTRIBUTION_NAME:-$DEFAULT_DISTRIBUTION_NAME}"
  CHROOT_DIR="${CHROOT_DIR:-/tmp/$WSL_DISTRIBUTION_NAME}"
  
  return 0
}

# Function to ensure Windows paths are in PATH
ensure_windows_paths() {
  # Check if Windows paths are already in PATH
  if echo "$PATH" | grep -q "/mnt/c/Windows"; then
    return 0
  fi
  
  echo "⚠️  Windows paths not in PATH. Attempting to add them..."
  
  # Common Windows paths that might contain wsl.exe
  WINDOWS_PATHS=(
    "/mnt/c/Windows/system32"
    "/mnt/c/Windows"
    "/mnt/c/Windows/System32/Wbem"
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/"
    "/mnt/c/Windows/System32/OpenSSH/"
  )
  
  # Add Windows paths to PATH
  for winpath in "${WINDOWS_PATHS[@]}"; do
    if [ -d "$winpath" ]; then
      export PATH="$PATH:$winpath"
    fi
  done
  
  # Verify we can now find wsl.exe
  if ! command -v wsl.exe &>/dev/null && ! [ -x "/mnt/c/Windows/system32/wsl.exe" ]; then
    echo "❌ Failed to locate wsl.exe even after adding Windows paths."
    echo "   Please run with: sudo -E $0"
    echo "   The -E flag preserves your environment variables including PATH."
    return 1
  fi
  
  echo "✅ Successfully added Windows paths to PATH"
  return 0
}

# Function to check sudo requirements and setup PATH
check_sudo_and_paths() {
  # Check if we need sudo
  if [ "$EUID" -ne 0 ]; then
    echo "❌ This script requires sudo privileges."
    echo "   Please run with: sudo $0"
    exit 1
  fi
  
  # Ensure Windows paths are available
  if ! ensure_windows_paths; then
    exit 1
  fi
}

# Function to find wsl.exe with fallback
find_wsl_exe() {
  # Try to find wsl.exe in PATH first
  if command -v wsl.exe &>/dev/null; then
    WSL_EXE="wsl.exe"
  elif [ -x "/mnt/c/Windows/system32/wsl.exe" ]; then
    WSL_EXE="/mnt/c/Windows/system32/wsl.exe"
  else
    echo "❌ Error: wsl.exe not found in PATH or at /mnt/c/Windows/system32/wsl.exe"
    echo "Make sure Windows Subsystem for Linux interoperability is working."
    echo "Current PATH: $PATH"
    return 1
  fi
  
  export WSL_EXE
  return 0
}

# Function to get real user's home directory when running with sudo
get_real_home() {
  local real_user="${SUDO_USER:-$USER}"
  
  # If we're root and SUDO_USER is not set, try to detect the real user
  if [ "$real_user" = "root" ] && [ -z "$SUDO_USER" ]; then
    # Try to get the user who owns the script
    local script_owner=$(stat -c '%U' "${BASH_SOURCE[-1]}" 2>/dev/null)
    if [ -n "$script_owner" ] && [ "$script_owner" != "root" ]; then
      real_user="$script_owner"
    fi
  fi
  
  # Return appropriate home directory
  if [ "$real_user" = "root" ]; then
    echo "/root"
  else
    echo "/home/$real_user"
  fi
}

# Function to get Windows username
get_windows_username() {
  cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n'
}

# Function to convert Linux path to Windows path
get_windows_path() {
  local linux_path="$1"
  if command -v wslpath &>/dev/null; then
    wslpath -w "$linux_path" 2>/dev/null
  else
    echo "$linux_path"
  fi
}

# Function to create WSL import directory
create_wsl_install_dir() {
  local distro_name="$1"
  local windows_user=$(get_windows_username)
  
  if [ -n "$windows_user" ] && [ -d "/mnt/c/Users/$windows_user" ]; then
    # Use Windows user directory
    local wsl_dir="/mnt/c/Users/$windows_user/WSL/$distro_name"
    mkdir -p "$wsl_dir"
    echo "$wsl_dir"
  else
    # Fallback to current directory
    echo "."
  fi
}

# Function to import WSL distribution
import_wsl_distribution() {
  local distro_name="$1"
  local tar_path="$2"
  local install_dir=$(create_wsl_install_dir "$distro_name")
  
  echo "Creating WSL installation directory: $install_dir"
  
  if [ "$install_dir" != "." ]; then
    local win_install_dir=$(get_windows_path "$install_dir")
    local win_tar_path=$(get_windows_path "$tar_path")
    
    echo "Windows install directory: $win_install_dir"
    echo "Windows tar path: $win_tar_path"
    
    $WSL_EXE --import "$distro_name" "$win_install_dir" "$win_tar_path"
  else
    echo "Could not determine Windows user directory, using current directory"
    $WSL_EXE --import "$distro_name" . "$tar_path"
  fi
}

# Function to get all possible WSL installation directories
get_wsl_install_dirs() {
  local distro_name="$1"
  local real_home=$(get_real_home)
  local windows_user=$(get_windows_username)
  
  local dirs=(
    "$real_home/.wsl/$distro_name"
    "/mnt/c/Users/$windows_user/WSL/$distro_name"
  )
  
  printf '%s\n' "${dirs[@]}"
}

# Function to check if a WSL distribution exists
distribution_exists() {
  local distro_name="$1"
  
  if [ -z "$distro_name" ]; then
    log_error "Distribution name not provided"
    return 2
  fi
  
  # Use WSL list to check, handling Unicode output
  if $WSL_EXE --list --all 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | grep -q "^${distro_name}$\|^${distro_name}[[:space:]]"; then
    return 0
  else
    return 1
  fi
}

# Function to get list of WSL distributions
get_wsl_distributions() {
  # Handle Unicode output from wsl --list
  $WSL_EXE --list --all 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | tr -d '\0\r' | grep -v "^Windows" | grep -v "^$" | sed 's/[[:space:]]*$//'
}

# Function to unregister a WSL distribution
unregister_distribution() {
  local distro_name="$1"
  
  if [ -z "$distro_name" ]; then
    log_error "Distribution name not provided"
    return 1
  fi
  
  if distribution_exists "$distro_name"; then
    log_progress "Unregistering WSL distribution: $distro_name"
    if $WSL_EXE --unregister "$distro_name" 2>&1; then
      log_success "Distribution $distro_name unregistered"
      return 0
    else
      log_error "Failed to unregister distribution $distro_name"
      return 1
    fi
  else
    log_warning "Distribution $distro_name not found"
    return 1
  fi
}

# Function to safely remove a file
safe_remove_file() {
  local file_path="$1"
  local description="${2:-file}"
  
  if [ -f "$file_path" ]; then
    if rm -f "$file_path"; then
      log_success "Removed $description: $file_path"
      return 0
    else
      log_warning "Failed to remove $description: $file_path"
      return 1
    fi
  fi
  return 0
}

# Function to safely remove a directory
safe_remove_dir() {
  local dir_path="$1"
  local description="${2:-directory}"
  
  if [ -d "$dir_path" ]; then
    if rm -rf "$dir_path"; then
      log_success "Removed $description: $dir_path"
      return 0
    else
      log_warning "Failed to remove $description: $dir_path"
      return 1
    fi
  fi
  return 0
}

# Function to clean up chroot directory
cleanup_chroot_dir() {
  local chroot_dir="$1"
  
  if [ -z "$chroot_dir" ]; then
    log_error "Chroot directory not specified"
    return 1
  fi
  
  if [ ! -d "$chroot_dir" ]; then
    return 0
  fi
  
  log_progress "Cleaning up chroot directory: $chroot_dir"
  
  # Try using the destroy script if it exists
  if [ -x "$chroot_dir/destroy" ]; then
    log_info "Using destroy script to clean up chroot"
    if $SUDO "$chroot_dir/destroy" -r; then
      log_success "Chroot directory cleaned up using destroy script"
      return 0
    else
      log_warning "Destroy script failed, attempting manual cleanup"
    fi
  fi
  
  # Manual cleanup as fallback
  log_info "Performing manual chroot cleanup"
  
  # Unmount any remaining mounts
  for mount in $(findmnt -R "$chroot_dir" -n -o TARGET | tac); do
    if [ "$mount" != "$chroot_dir" ]; then
      log_info "Unmounting $mount"
      $SUDO umount "$mount" 2>/dev/null || true
    fi
  done
  
  # Remove the directory
  if $SUDO rm -rf "$chroot_dir"; then
    log_success "Chroot directory removed"
    return 0
  else
    log_error "Failed to remove chroot directory"
    return 1
  fi
}

# Function to clean up WSL installation directories
cleanup_wsl_dirs() {
  local distro_name="$1"
  
  for wsl_dir in $(get_wsl_install_dirs "$distro_name"); do
    if [ -d "$wsl_dir" ]; then
      echo "🗑️ Removing WSL installation directory: $wsl_dir"
      rm -rf "$wsl_dir" || echo "⚠️ Warning: Failed to remove $wsl_dir"
    fi
  done
}