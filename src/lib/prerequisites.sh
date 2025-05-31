#!/usr/bin/env bash
# ABOUTME: Prerequisites checking for Alpine WSL build
# ABOUTME: Validates system requirements and dependencies

# Prevent multiple sourcing
[[ -n "${__PREREQUISITES_SH_LOADED:-}" ]] && return 0
__PREREQUISITES_SH_LOADED=1

# Source common functions if not already loaded
if [[ -z "${__COMMON_SH_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/common.sh"
fi

# Function aliases for compatibility
progress() { log_progress "$@"; }
debug() { log_debug "$@"; }
error() { log_error "$@"; }
verbose() { log_verbose "$@"; }
warning() { log_warning "$@"; }
success() { log_info "✓ $*"; }
info() { log_info "$@"; }

# Required commands
REQUIRED_COMMANDS=(wget tar gzip sha256sum fakeroot)

# Check if a command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check all prerequisites
check_prerequisites() {
    progress "Checking prerequisites..."
    
    local missing=()
    local cmd
    
    # Check required commands
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        debug "Checking for command: $cmd"
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
            debug "$cmd is missing"
        else
            debug "$cmd found at: $(command -v "$cmd")"
        fi
    done
    
    # Check for WSL
    debug "Checking for WSL environment..."
    if ! command_exists wsl.exe; then
        error "wsl.exe not found. This script must be run from within WSL."
        return 1
    fi
    
    # Check WSL version
    if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        verbose "Running in WSL2"
    else
        verbose "Running in WSL1"
    fi
    
    # Report missing commands
    if [[ ${#missing[@]} -ne 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        echo "Please install them and try again:"
        echo "  sudo apt-get update && sudo apt-get install -y ${missing[*]}"
        return 1
    fi
    
    # Check disk space
    local available_space
    available_space=$(df -BG "${TMPDIR:-/tmp}" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 2 ]]; then
        warning "Low disk space: ${available_space}GB available (2GB recommended)"
    fi
    
    success "All prerequisites found"
    return 0
}

# Get system information
get_system_info() {
    verbose "System information:"
    verbose "  OS: $(uname -o)"
    verbose "  Kernel: $(uname -r)"
    verbose "  Architecture: $(uname -m)"
    verbose "  WSL Version: $(wsl.exe --version 2>/dev/null | head -1 || echo "Unknown")"
}