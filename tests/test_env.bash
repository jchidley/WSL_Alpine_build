#!/usr/bin/env bash
# Test environment configuration for consistent test execution

# Detect if we're in a test environment
export BATS_TEST_ENVIRONMENT=1
export WSL_TEST_MODE=1

# Disable all interactive features
export DEBIAN_FRONTEND=noninteractive
export NONINTERACTIVE=1

# Logging configuration for tests
export LOG_LEVEL=ERROR      # Only show errors
export DEBUG=0              # Disable debug by default
export VERBOSE=0            # Disable verbose by default
export NO_COLOR=1           # Disable color output for cleaner assertions
export TERM=dumb           # Simple terminal for consistent output

# Disable file logging during tests
unset LOG_FILE

# Disable syslog during tests
export DISABLE_SYSLOG=1

# Output control
export QUIET_MODE=1         # Minimize output
export TEST_OUTPUT_ONLY=1   # Only output what tests need

# Mock system behavior
export MOCK_WSL_UNICODE=0   # Don't use UTF-16LE conversion in mocks
export SKIP_REAL_WSL_CHECK=1 # Skip checking for real WSL

# Consistent test paths
export TEST_HOME="/tmp/test-home"
export TEST_USER="testuser"
export USER="$TEST_USER"
export HOME="$TEST_HOME"

# Function to strip ANSI color codes
strip_ansi() {
    sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' | sed 's/\x1B\[[0-9;]*m//g'
}

# Function to normalize output for testing
normalize_output() {
    # Strip ANSI codes, trim whitespace, remove empty lines
    strip_ansi | sed 's/[[:space:]]*$//' | grep -v '^$' || true
}

# Function to extract just the essential output
extract_essential() {
    # Remove log prefixes and timestamps
    sed -E 's/^\[[^]]+\] //g' | \
    sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} //g' | \
    normalize_output
}

# Export functions for use in tests
export -f strip_ansi normalize_output extract_essential

# Create consistent test environment
setup_test_env() {
    # Create test home
    mkdir -p "$TEST_HOME"
    
    # Set predictable environment
    export PATH="/usr/local/bin:/usr/bin:/bin"
    export SHELL="/bin/bash"
    export LANG=C
    export LC_ALL=C
    
    # Mock system info
    export WSL_DISTRO_NAME="test-distro"
    export WSL_INTEROP="/dev/null"
}

# Override logging functions for tests
if [[ -n "$BATS_TEST_ENVIRONMENT" ]]; then
    # Simplified logging that doesn't interfere with test output
    log_info() { [[ "$QUIET_MODE" != "1" ]] && echo "$*" >&2; }
    log_error() { echo "ERROR: $*" >&2; }
    log_warning() { [[ "$QUIET_MODE" != "1" ]] && echo "WARNING: $*" >&2; }
    log_debug() { [[ "$DEBUG" == "1" ]] && echo "DEBUG: $*" >&2; }
    log_verbose() { [[ "$VERBOSE" == "1" ]] && echo "VERBOSE: $*" >&2; }
    log_progress() { [[ "$QUIET_MODE" != "1" ]] && echo "$*" >&2; }
    
    # Export overridden functions
    export -f log_info log_error log_warning log_debug log_verbose log_progress
fi