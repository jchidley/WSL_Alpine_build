#!/usr/bin/env bash
# ABOUTME: Common functions and variables for Alpine WSL build
# ABOUTME: Provides logging, error handling, and utility functions

# Prevent multiple sourcing
[[ -n "${__COMMON_SH_LOADED:-}" ]] && return 0
__COMMON_SH_LOADED=1

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'  # No Color

# Global settings
export SCRIPT_NAME="${SCRIPT_NAME:-$(basename "${BASH_SOURCE[0]}")}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export DEBUG="${DEBUG:-0}"
export VERBOSE="${VERBOSE:-0}"
export DRY_RUN="${DRY_RUN:-0}"

# Constants
export DEFAULT_DISTRIBUTION_NAME="alp2"
export TEST_DISTRIBUTION_PREFIX="alp-test-"
export TEST_DISTRIBUTION_PATTERN="${TEST_DISTRIBUTION_PREFIX}[0-9]+"

# Logging functions with consistent output
log_info() {
    echo -e "${BLUE}ℹ${NC}  $*" >&2
    log "INFO" "$*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*" >&2
    log "SUCCESS" "$*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
    log "ERROR" "$*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $*" >&2
    log "WARNING" "$*"
}

log_progress() {
    echo -e "${BLUE}→${NC} $*" >&2
    log "PROGRESS" "$*"
}

log_debug() {
    if [[ "$DEBUG" == "1" ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $*" >&2
        log "DEBUG" "$*"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "1" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*" >&2
        log "VERBOSE" "$*"
    fi
}

# Logging to file and syslog
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Also log to syslog if available (but don't fail if not)
    if command -v logger >/dev/null 2>&1; then
        logger -t "$SCRIPT_NAME" "[$level] $message" 2>/dev/null || true
    fi
}

# Check if running in dry run mode
is_dry_run() {
    [[ "$DRY_RUN" == "1" ]]
}

# Execute command or show what would be done in dry run mode
dry_run_exec() {
    if is_dry_run; then
        echo "[DRY RUN] Would execute: $*"
        return 0
    else
        "$@"
    fi
}

# Die function for fatal errors
die() {
    log_error "$*"
    exit 1
}

# Configuration loading function
load_config() {
    local env_file="${1:-.env}"
    
    if [[ ! -f "$env_file" ]]; then
        log_warning "No $env_file file found"
        return 1
    fi
    
    log_debug "Loading configuration from $env_file"
    
    # Source the .env file
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
    
    # Set defaults for critical variables
    SUDO="${SUDO:-sudo}"
    WSL_DISTRIBUTION_NAME="${WSL_DISTRIBUTION_NAME:-$DEFAULT_DISTRIBUTION_NAME}"
    CHROOT_DIR="${CHROOT_DIR:-/tmp/$WSL_DISTRIBUTION_NAME}"
    
    log_debug "Configuration loaded: WSL_DISTRIBUTION_NAME=$WSL_DISTRIBUTION_NAME"
    return 0
}

# Function to ensure Windows paths are in PATH
ensure_windows_paths() {
    # Check if Windows paths are already in PATH
    if echo "$PATH" | grep -q "/mnt/c/Windows"; then
        return 0
    fi
    
    log_warning "Windows paths not in PATH. Attempting to add them..."
    
    # Common Windows paths that might contain wsl.exe
    local windows_paths=(
        "/mnt/c/Windows/system32"
        "/mnt/c/Windows"
        "/mnt/c/Windows/System32/Wbem"
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/"
        "/mnt/c/Windows/System32/OpenSSH/"
    )
    
    # Add Windows paths to PATH
    for winpath in "${windows_paths[@]}"; do
        if [[ -d "$winpath" ]]; then
            export PATH="$PATH:$winpath"
        fi
    done
    
    # Verify we can now find wsl.exe
    if ! command -v wsl.exe &>/dev/null && ! [[ -x "/mnt/c/Windows/system32/wsl.exe" ]]; then
        log_error "Failed to locate wsl.exe even after adding Windows paths."
        log_error "Please run with: sudo -E $0"
        log_error "The -E flag preserves your environment variables including PATH."
        return 1
    fi
    
    log_success "Successfully added Windows paths to PATH"
    return 0
}

# Function to check sudo requirements and setup PATH
check_sudo_and_paths() {
    # Check if we need sudo
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script requires sudo privileges."
        log_error "Please run with: sudo $0"
        exit 1
    fi
    
    # Ensure Windows paths are available
    if ! ensure_windows_paths; then
        exit 1
    fi
}

# Validate that WSL interop is healthy (WSLInterop binfmt + executable launch)
validate_wsl_interop() {
    # Skip deep checks in tests/mocks
    if [[ "${WSL_EXE:-}" == *"/mocks/"* ]] || [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        return 0
    fi

    # If execution works, interop is good enough
    if "$WSL_EXE" --status >/dev/null 2>&1 || "$WSL_EXE" --list --quiet >/dev/null 2>&1; then
        return 0
    fi

    log_error "Windows interop appears broken (cannot execute wsl.exe)."
    log_error "Expected in WSL: /proc/sys/fs/binfmt_misc/WSLInterop with interpreter /init"
    log_error "Fix steps:"
    log_error "  1) Ensure /etc/wsl.conf contains:"
    log_error "     [interop]"
    log_error "     enabled=true"
    log_error "     appendWindowsPath=true"
    log_error "  2) From Windows PowerShell run: wsl --shutdown"
    log_error "  3) Reopen distro and verify: powershell.exe -NoProfile -Command 'Write-Output ok'"
    log_error "Emergency in-session repair:"
    log_error "  echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /proc/sys/fs/binfmt_misc/register"

    return 1
}

# Function to find wsl.exe with fallback
find_wsl_exe() {
    # Try to find wsl.exe in PATH first
    if command -v wsl.exe &>/dev/null; then
        WSL_EXE="wsl.exe"
    elif [[ -x "/mnt/c/Windows/system32/wsl.exe" ]]; then
        WSL_EXE="/mnt/c/Windows/system32/wsl.exe"
    else
        log_error "wsl.exe not found in PATH or at /mnt/c/Windows/system32/wsl.exe"
        log_error "Make sure Windows Subsystem for Linux interoperability is working."
        log_error "Current PATH: $PATH"
        return 1
    fi

    export WSL_EXE

    if ! validate_wsl_interop; then
        return 1
    fi

    log_debug "Found WSL executable at: $WSL_EXE"
    return 0
}

# Function to get real user's home directory when running with sudo
get_real_home() {
    local real_user="${SUDO_USER:-$USER}"
    
    # If we're root and SUDO_USER is not set, try to detect the real user
    if [[ "$real_user" = "root" ]] && [[ -z "$SUDO_USER" ]]; then
        # Try to get the user who owns the script
        local script_owner
        script_owner=$(stat -c '%U' "${BASH_SOURCE[-1]}" 2>/dev/null)
        if [[ -n "$script_owner" ]] && [[ "$script_owner" != "root" ]]; then
            real_user="$script_owner"
        fi
    fi
    
    # Return appropriate home directory
    if [[ "$real_user" = "root" ]]; then
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
    local windows_user
    windows_user=$(get_windows_username)
    
    if [[ -n "$windows_user" ]] && [[ -d "/mnt/c/Users/$windows_user" ]]; then
        # Use Windows user directory
        local wsl_dir="/mnt/c/Users/$windows_user/WSL/$distro_name"
        mkdir -p "$wsl_dir"
        echo "$wsl_dir"
    else
        # Fallback to current directory
        echo "."
    fi
}

# Function to check if a WSL distribution exists
distribution_exists() {
    local distro_name="$1"

    if [[ -z "$distro_name" ]]; then
        log_error "Distribution name not provided"
        return 2
    fi

    # Ensure WSL_EXE is set
    if [[ -z "${WSL_EXE:-}" ]]; then
        if ! find_wsl_exe; then
            return 2
        fi
    fi

    # Check if we're using a mock (output is already UTF-8)
    if [[ "$WSL_EXE" == *"/mocks/"* ]] || [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        if "$WSL_EXE" --list --all 2>/dev/null | grep -q "^${distro_name}$\|^${distro_name}[[:space:]]"; then
            return 0
        fi
    else
        if "$WSL_EXE" --list --all 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | grep -q "^${distro_name}$\|^${distro_name}[[:space:]]"; then
            return 0
        fi
    fi

    return 1
}

# Function to get list of WSL distributions
get_wsl_distributions() {
    # Check if we're using a mock (output is already UTF-8)
    if [[ "$WSL_EXE" == *"/mocks/"* ]] || [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        "$WSL_EXE" --list --all 2>/dev/null | tr -d '\0\r' | grep -v "^Windows" | grep -v "^$" | sed 's/[[:space:]]*$//'
    else
        "$WSL_EXE" --list --all 2>/dev/null | iconv -f UTF-16LE -t UTF-8 2>/dev/null | tr -d '\0\r' | grep -v "^Windows" | grep -v "^$" | sed 's/[[:space:]]*$//'
    fi
}

# Function to safely remove a file
safe_remove_file() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [[ -f "$file_path" ]]; then
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
    
    if [[ -d "$dir_path" ]]; then
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

# Cleanup function (can be overridden by scripts)
cleanup() {
    log_debug "Running cleanup..."
    # This will be overridden by scripts that source this
    :
}

# Error handler
on_error() {
    local line=$1
    local code=${2:-1}
    local cmd="${BASH_COMMAND}"
    
    log_error "Command failed at line $line with exit code $code"
    log_error "Failed command: $cmd"
    
    if [[ "$DEBUG" == "1" ]]; then
        log_error "Call stack:"
        local frame=0
        while caller $frame >&2; do
            ((frame++))
        done
    fi
    
    cleanup
    exit "$code"
}

# Set up error handling
setup_error_handling() {
    set -euo pipefail
    trap 'on_error $LINENO $?' ERR
    
    # Enhanced debug mode
    if [[ "$DEBUG" == "1" ]]; then
        export PS4='+ $(date "+%H:%M:%S.%3N") [${BASH_SOURCE##*/}:${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}()} '
        set -x
    fi
}

# Command checking function
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Dependency verification
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install the missing dependencies and try again."
        return 1
    fi
    
    return 0
}

# Create temporary directory with cleanup
create_temp_dir() {
    local prefix="${1:-alpine-wsl}"
    local temp_dir
    
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    log_debug "Created temporary directory: $temp_dir"
    
    # Add to cleanup on exit
    trap "rm -rf '$temp_dir'" EXIT
    
    echo "$temp_dir"
}

# Validation function for distribution names
validate_distribution_name() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Distribution name cannot be empty"
        return 1
    fi
    
    # Check for valid characters (alphanumeric, dash, underscore)
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Distribution name can only contain letters, numbers, dash, and underscore"
        return 1
    fi
    
    # Check length
    if [[ ${#name} -gt 64 ]]; then
        log_error "Distribution name must be 64 characters or less"
        return 1
    fi
    
    return 0
}

# Export all functions
export -f log_info log_success log_error log_warning log_progress log_debug log_verbose
export -f log die is_dry_run dry_run_exec
export -f load_config ensure_windows_paths check_sudo_and_paths validate_wsl_interop find_wsl_exe
export -f get_real_home get_windows_username get_windows_path create_wsl_install_dir
export -f distribution_exists get_wsl_distributions
export -f safe_remove_file safe_remove_dir
export -f cleanup on_error setup_error_handling
export -f command_exists check_dependencies create_temp_dir validate_distribution_name