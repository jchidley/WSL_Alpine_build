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