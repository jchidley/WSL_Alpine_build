#!/usr/bin/env bats
# Integration tests for the complete build workflow
# Focused on testing OUR logic, not system behavior

load ../test_helper

@test "build: wsl-alpine script is executable" {
    assert_file_exists "$PROJECT_ROOT/wsl-alpine"
    [[ -x "$PROJECT_ROOT/wsl-alpine" ]]
}

@test "build: help command works" {
    run_command "$PROJECT_ROOT/wsl-alpine" help
    assert_success
    assert_output_contains "Alpine WSL Management Tool"
    assert_output_contains "Commands:"
}

@test "build: version flag shows version" {
    run_command "$PROJECT_ROOT/wsl-alpine" --version
    assert_success
    assert_output_contains "Alpine WSL Management Tool v"
}

@test "build: module list command works" {
    run_command "$PROJECT_ROOT/wsl-alpine" module list
    assert_success
    assert_output_contains "Available modules:"
    assert_output_contains "base"
}

@test "build: module info shows module details" {
    run_command "$PROJECT_ROOT/wsl-alpine" module info base
    assert_success
    assert_output_contains "Module: base"
}

@test "build: command validates inputs" {
    # Invalid distribution name
    run_command "$PROJECT_ROOT/wsl-alpine" build --name "invalid@name"
    assert_failure
    assert_output_contains "only contain letters"
}

@test "build: unknown build option is rejected" {
    run_command "$PROJECT_ROOT/wsl-alpine" build --definitely-invalid-option
    assert_failure
    assert_output_contains "Unknown option"
}


@test "build: reset command requires distribution name" {
    run_command "$PROJECT_ROOT/wsl-alpine" reset
    assert_failure
    assert_output_contains "Distribution name required"
}

@test "build: all modules can be loaded" {
    # Test that all module install scripts are valid
    for module_dir in "$PROJECT_ROOT"/src/modules/*/; do
        if [[ -d "$module_dir" ]]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            # Check files exist
            assert_file_exists "$module_dir/install.sh"
            assert_file_exists "$module_dir/metadata.yaml"
        fi
    done
}

@test "build: configuration loading works" {
    # Create test config
    cat > "$TEST_TEMP_DIR/test.env" << CONF
WSL_DISTRIBUTION_NAME=test-from-config
ALPINE_VERSION=3.19.0
CONF
    
    # Test that config is loaded
    run_command bash -c "
        cd '$PROJECT_ROOT'
        source src/lib/common.sh
        load_config '$TEST_TEMP_DIR/test.env'
        echo \"Name: \$WSL_DISTRIBUTION_NAME\"
        echo \"Version: \$ALPINE_VERSION\"
    "
    
    assert_success
    assert_output_contains "Name: test-from-config"
    assert_output_contains "Version: 3.19.0"
}

@test "build: error handling works" {
    # Test that error handler is called
    run_command bash -c "
        cd '$PROJECT_ROOT'
        source src/lib/common.sh
        setup_error_handling
        
        # This should trigger error handler
        false
    "
    
    assert_failure
    assert_output_contains "Command failed"
}

# Note: Full build workflow testing requires a real WSL environment with network
# access. These integration tests are designed to be run manually or in CI
# environments that have the necessary prerequisites. The unit tests cover
# all the individual components and their interactions.
