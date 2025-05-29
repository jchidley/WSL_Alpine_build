#!/bin/bash
# ABOUTME: Common functions and variables for Alpine WSL build
# ABOUTME: Provides colors, logging, and utility functions

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

# Progress indicator
progress() {
    echo -e "${BLUE}→${NC} $1"
    [[ "${VERBOSE:-0}" == "1" ]] && log "PROGRESS" "$1" || true
}

# Success message
success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS" "$1" || true
}

# Error message
error() {
    echo -e "${RED}✗${NC} $1" >&2
    log "ERROR" "$1" || true
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARNING" "$1" || true
}

# Debug message
debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
    [[ "${DEBUG:-0}" == "1" ]] && log "DEBUG" "$1" || true
}

# Verbose message
verbose() {
    [[ "${VERBOSE:-0}" == "1" ]] && echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    [[ "${VERBOSE:-0}" == "1" ]] && log "VERBOSE" "$1" || true
}

# Logging function
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
    [[ "${DRY_RUN:-0}" == "1" ]]
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

# Cleanup function
cleanup() {
    debug "Running cleanup..."
    # This will be overridden by scripts that source this
    :
}

# Error handler
on_error() {
    local line=$1
    local code=${2:-1}
    local cmd="${BASH_COMMAND}"
    
    error "Command failed at line $line with exit code $code"
    error "Failed command: $cmd"
    
    if [[ "${DEBUG:-0}" == "1" ]]; then
        error "Call stack:"
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
    if [[ "${DEBUG:-0}" == "1" ]]; then
        export PS4='+ $(date "+%H:%M:%S.%3N") [${BASH_SOURCE##*/}:${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}()} '
        set -x
    fi
}