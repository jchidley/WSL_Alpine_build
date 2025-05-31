# Testing Strategy

## Overview

The WSL Alpine Build test suite follows the principle of "Test What You Own, Not What You Use". We focus on testing our logic, validation, and error handling rather than verifying that operating system commands work correctly.

## Test Categories

### 1. Unit Tests (`tests/unit/`)
- **Purpose**: Test individual functions and libraries in isolation
- **Coverage**: 30 tests covering all core libraries
- **Run with**: `./wsl-alpine test --unit`
- **Examples**:
  - URL generation logic
  - Configuration validation
  - Error message formatting
  - Distribution name validation

### 2. Integration Tests (`tests/integration/`)
- **Purpose**: Test component interactions and workflows
- **Coverage**: 28 tests covering script integration
- **Run with**: `./wsl-alpine test --integration`
- **Examples**:
  - Command-line interface behavior
  - Module loading and configuration
  - Build workflow coordination

### 3. Real Environment Tests (`tests/integration/test_real_environment.bats`)
- **Purpose**: Test actual system operations with real resources
- **Coverage**: 4 tests requiring network/WSL
- **Run with**: `./wsl-alpine test --real`
- **Requires**: `RUN_INTEGRATION_TESTS=1` environment variable
- **Examples**:
  - Real minirootfs downloads
  - Actual WSL operations
  - Full build workflow with real components

## Test Execution

### Default Test Run
```bash
./wsl-alpine test
```
Runs all unit and integration tests (58 tests total), excluding real environment tests.

### Specific Test Types
```bash
./wsl-alpine test --unit         # Unit tests only (30 tests)
./wsl-alpine test --integration  # Integration tests only (28 tests)
./wsl-alpine test --real         # Real environment tests (4 tests)
```

### Direct BATS Execution
```bash
# Run specific test file
bats tests/unit/test_common.bats

# Run with specific environment
RUN_INTEGRATION_TESTS=1 bats tests/integration/test_real_environment.bats
```

## Test Infrastructure

### Test Environment (`tests/test_env.bash`)
- Disables interactive features and colors
- Sets up consistent paths and variables
- Provides output normalization functions
- Overrides logging for clean test output

### Test Helpers (`tests/test_helper.bash`)
- Common setup/teardown functions
- Assertion utilities
- Mock creation helpers
- Test data generators

### Mocks (`tests/mocks/`)
- `wsl-mock.sh`: Sophisticated WSL simulator with state management
- Simulates WSL operations without requiring Windows

## What We Don't Test

We explicitly avoid testing:
1. **OS Command Behavior**: Whether `mkdir` creates directories
2. **External Tool Functionality**: Whether `wget` downloads files
3. **System Dependencies**: Whether `tar` extracts archives
4. **Environment-Specific Operations**: Real network downloads, actual WSL imports

These are covered by:
- Trusting that standard tools work as documented
- Manual testing during development
- Real environment tests when explicitly requested
- User acceptance testing in production

## Test Philosophy

1. **Fast Feedback**: Default tests run in seconds, not minutes
2. **Reliable Results**: No flaky tests dependent on external resources
3. **Clear Failures**: Tests fail with meaningful error messages
4. **Isolation**: Each test runs in a clean environment
5. **Maintainability**: Tests are easy to understand and modify

## Adding New Tests

When adding features:
1. Write unit tests for new functions
2. Test error conditions and edge cases
3. Add integration tests for user-facing changes
4. Document any real environment requirements
5. Keep tests focused and independent

## Continuous Integration

The test suite is designed for CI/CD:
- No external dependencies for default tests
- Consistent results across environments
- Clear pass/fail status
- Optional real environment tests for release validation