#!/usr/bin/env bats
# Integration tests for the complete build workflow

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
    assert_output_contains "build"
    assert_output_contains "reset"
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
    assert_output_contains "docker"
    assert_output_contains "claude-code"
    assert_output_contains "development"
}

@test "build: module info shows module details" {
    run_command "$PROJECT_ROOT/wsl-alpine" module info base
    assert_success
    assert_output_contains "Module: base"
    assert_output_contains "Base Alpine system"
}

@test "build: list command shows distributions" {
    run_command "$PROJECT_ROOT/wsl-alpine" list
    assert_success
    assert_output_contains "WSL Distributions:"
    # Should show our mock distributions
    assert_output_contains "Debian"
    assert_output_contains "alp2"
}

@test "build: dry run mode prevents changes" {
    # Create test archive
    local test_archive
    test_archive=$(create_test_minirootfs)
    
    # Run build in dry run mode
    DRY_RUN=1 run_command "$PROJECT_ROOT/wsl-alpine" --dry-run build \
        --name test-dry-run \
        --modules base \
        --build-dir "$TEST_TEMP_DIR/build" \
        --no-import
    
    assert_success
    assert_output_contains "[DRY RUN]"
}

@test "build: build command validates inputs" {
    # Invalid distribution name
    run_command "$PROJECT_ROOT/wsl-alpine" build --name "invalid@name"
    assert_failure
    assert_output_contains "only contain letters"
}

@test "build: reset command requires distribution name" {
    run_command "$PROJECT_ROOT/wsl-alpine" reset
    assert_failure
    assert_output_contains "Distribution name required"
}

@test "build: reset command works with valid name" {
    run_command "$PROJECT_ROOT/wsl-alpine" reset alp2
    assert_success
    assert_output_contains "Unregistering distribution: alp2"
}

@test "build: test command runs self-tests" {
    skip "Recursive test execution"
    
    # This would run the test suite recursively
    # run_command "$PROJECT_ROOT/wsl-alpine" test --unit
    # assert_success
}

@test "build: build with base module only" {
    skip_if_ci
    skip_if_missing_command tar
    skip_if_missing_command gzip
    
    # Mock wget and other external commands
    mock_wget
    
    # Create a minimal test that simulates build
    run_command bash -c "
        cd '$PROJECT_ROOT'
        # Override external commands
        export PATH='$TEST_TEMP_DIR/mocks:$PATH'
        
        # Create mock fakeroot
        cat > '$TEST_TEMP_DIR/mocks/fakeroot' << 'EOF'
#!/bin/bash
shift  # Remove --
\"\$@\"
EOF
        chmod +x '$TEST_TEMP_DIR/mocks/fakeroot'
        
        # Run build
        ./wsl-alpine build \
            --name test-integration \
            --modules base \
            --build-dir '$TEST_TEMP_DIR/build' \
            --output test.tar.gz \
            --no-import
    "
    
    # Build should create necessary directories
    assert_dir_exists "$TEST_TEMP_DIR/build"
}

@test "build: all modules can be loaded" {
    # Test that all module install scripts are valid
    for module_dir in "$PROJECT_ROOT"/src/modules/*/; do
        if [[ -d "$module_dir" ]]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            # Check install script exists and is executable
            if [[ -f "$module_dir/install.sh" ]]; then
                assert_file_exists "$module_dir/install.sh"
                [[ -x "$module_dir/install.sh" ]]
                
                # Check metadata exists
                assert_file_exists "$module_dir/metadata.yaml"
                
                # Verify install script sources correctly
                run_command bash -c "
                    export ROOTFS_DIR='$TEST_TEMP_DIR/rootfs'
                    source '$module_dir/install.sh' 2>&1 | head -n 5
                "
                # Should at least load without immediate errors
                assert_output_contains "Installing $module_name module"
            fi
        fi
    done
}

@test "build: configuration loading works" {
    # Create test config
    cat > "$TEST_TEMP_DIR/test.env" << EOF
WSL_DISTRIBUTION_NAME=test-from-config
ALPINE_VERSION=3.19.0
DOCKER_ENABLED=false
EOF
    
    # Test that config is loaded
    run_command bash -c "
        cd '$PROJECT_ROOT'
        source src/lib/common.sh
        load_config '$TEST_TEMP_DIR/test.env'
        echo \"Name: \$WSL_DISTRIBUTION_NAME\"
        echo \"Version: \$ALPINE_VERSION\"
        echo \"Docker: \$DOCKER_ENABLED\"
    "
    
    assert_success
    assert_output_contains "Name: test-from-config"
    assert_output_contains "Version: 3.19.0"
    assert_output_contains "Docker: false"
}

@test "build: error handling catches failures" {
    # Create a script that will fail
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

@test "build: cleanup runs on error" {
    # Test that cleanup is called on error
    run_command bash -c "
        cd '$PROJECT_ROOT'
        source src/lib/common.sh
        
        # Define cleanup that writes a file
        cleanup() {
            echo 'Cleanup was called' > '$TEST_TEMP_DIR/cleanup-marker'
        }
        
        setup_error_handling
        
        # Trigger error
        false
    "
    
    assert_failure
    # Cleanup should have been called
    assert_file_exists "$TEST_TEMP_DIR/cleanup-marker"
    assert_file_contains "$TEST_TEMP_DIR/cleanup-marker" "Cleanup was called"
}