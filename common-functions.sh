#!/usr/bin/env bash
# Common functions for WSL Alpine build scripts

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
  echo "/home/$real_user"
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