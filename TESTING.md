# Testing WSL Alpine Build Scripts

This document describes approaches for testing the WSL Alpine build scripts from within a WSL environment, with emphasis on safety and avoiding damage to existing WSL installations.

## ⚠️ SAFETY WARNINGS ⚠️

- **DISTRIBUTION NAME CONFLICTS**: Scripts may overwrite existing WSL distributions with the same name
- **BACKUP FIRST**: Always back up important WSL distributions before testing
- **USE UNIQUE TEST NAMES**: Always use unique distribution names with timestamps (e.g., "alp-test-20240520123045")
- **CHECK WSL LISTS**: Run `wsl.exe -l -v` before testing to see which distributions already exist
- **AVOID PRODUCTION SYSTEMS**: Do not test on systems where WSL is used for production work
- **ADMINISTRATIVE ACCESS**: Some operations require Windows administrative privileges
- **DISK SPACE**: Ensure at least 1GB of free space for testing

## Prerequisites

- Windows 10/11 with WSL 2 enabled
- A WSL distribution (Debian, Ubuntu, etc.) installed and running
- Administrator privileges on Windows
- WSL interoperability (ability to run Windows executables from WSL)
- Required tools: `sudo`, `wget`, `sed`, `tar`, `gzip`

## Using the Test Script

The repository includes an enhanced `wsl-alpine-test.sh` script with several testing options:

### Test Options

1. **Standard Test**: Performs a complete build and verification
2. **Quick Test**: Only verifies WSL commands without building a distribution
3. **Advanced Test**: Allows customizing Alpine version and packages before testing
4. **Exit**: Cancels testing

### Running the Test Script

```bash
# Make the script executable
chmod +x wsl-alpine-test.sh

# Run the test script
./wsl-alpine-test.sh
```

### What the Test Script Does

1. Creates a unique timestamped distribution name to avoid conflicts
2. Verifies WSL command access and environment
3. Creates a temporary test configuration (.env file)
4. Offers test options menu for different test types
5. Builds and installs the distribution (for standard/advanced tests)
6. Verifies the installation:
   - Checks that the distribution appears in the WSL list
   - Tests running basic commands
   - Verifies the Alpine version
   - Checks for installed packages and utilities
7. Provides cleanup options:
   - Remove the test distribution
   - Keep it for further inspection

## Manual Testing

For situations where more control is needed, you can test manually:

1. **Create Test Environment**:
   ```bash
   # Create a timestamped distribution name
   TIMESTAMP=$(date +%Y%m%d%H%M%S)
   
   # Create test .env file
   cat > test.env << EOF
   SUDO=sudo
   WSL_DISTRIBUTION_NAME=alp-test-$TIMESTAMP
   CHROOT_DIR="/tmp/alp-test-$TIMESTAMP"
   EOF
   
   # Use the test environment
   cp test.env .env
   ```

2. **Run and Monitor the Build**:
   ```bash
   # Run with verbose output and logging
   ./wsl-alpine-build.sh 2>&1 | tee build.log
   ```

3. **Verify Installation**:
   ```bash
   # Check if distribution was created
   wsl.exe -l -v
   
   # Test running commands in the distribution
   wsl.exe -d alp-test-$TIMESTAMP -e echo "Test successful"
   
   # Check Alpine version
   wsl.exe -d alp-test-$TIMESTAMP -e cat /etc/alpine-release
   ```

4. **Test Cleanup**:
   ```bash
   # Restore original .env if needed
   mv .env.bak .env
   
   # Test reset script with the test distribution
   WSL_DISTRIBUTION_NAME=alp-test-$TIMESTAMP ./wsl-alpine-reset.sh
   ```

## Testing Advanced Configurations

To test with custom Alpine versions or package selections:

```bash
# Set the environment variables
cat > .env << EOF
SUDO=sudo
WSL_DISTRIBUTION_NAME=alp-test-$(date +%Y%m%d%H%M%S)
CHROOT_DIR="/tmp/alp-test-$(date +%Y%m%d%H%M%S)"
ALPINE_VERSION=v3.18
EXTRA_PACKAGES="vim git curl"
EOF

# Run the build script
./wsl-alpine-build.sh
```

## Using the Cleanup Script

For comprehensive cleanup of test distributions:

```bash
# Remove all distributions with names matching the alp-test-* pattern
./wsl-alpine-test-cleanup.sh

# View all distributions but only remove test ones
./wsl-alpine-test-cleanup.sh --all

# Use a custom pattern for test distributions
./wsl-alpine-test-cleanup.sh --pattern "alpine-custom-.*"

# Get help on cleanup options
./wsl-alpine-test-cleanup.sh --help
```

## Debugging Tips

- **WSL Interoperability Check**:
  ```bash
  # Check WSL status and interoperability
  wsl.exe --status
  
  # Get more detailed information about WSL
  wsl.exe --version
  ```

- **Windows Path Conversion**:
  ```bash
  # Convert Windows path to WSL path
  win_path="C:\Users\username\Documents"
  wsl_path=$(echo "$win_path" | sed 's/\\/\//g; s/^\([A-Za-z]\):/\/mnt\/\L\1/')
  echo "$wsl_path"  # Output: /mnt/c/Users/username/Documents
  ```

- **Detailed Bash Debugging**:
  ```bash
  # Enable bash debug mode for verbose output
  bash -x ./wsl-alpine-build.sh 2>&1 | tee debug.log
  
  # Trace all script execution with line numbers
  bash -xv ./wsl-alpine-build.sh 2>&1 | tee debug-verbose.log
  ```

- **Permission Issues**:
  ```bash
  # Check & fix permissions on chroot directory
  sudo chown -R $(id -u):$(id -g) "$CHROOT_DIR"
  
  # Check if sudo is configured correctly
  sudo -v
  ```

- **Check Alpine Repository Access**:
  ```bash
  # Verify connectivity to Alpine repositories
  wget -q --spider https://dl-cdn.alpinelinux.org/alpine/edge/main
  echo $?  # Should return 0 if successful
  ```

- **Verify WSL Installation Command**:
  ```bash
  # Check if wsl.exe --install --from-file is supported
  wsl.exe --help | grep -- --from-file
  ```

- **Test Distribution Health**:
  ```bash
  # Verify basic functionality of a created distribution
  wsl.exe -d distribution-name -e ash -c "echo 'Alpine' && cat /etc/alpine-release && apk --version"
  ```

## Common Issues and Solutions

### Distribution Creation Failures

If the distribution fails to create, check:

1. **WSL Version**: Ensure you have WSL 2 with the `--from-file` option
   ```bash
   wsl.exe --version
   # Should be at least 1.2.5.0 or higher
   ```

2. **File Permissions**: Ensure the temporary files are accessible
   ```bash
   ls -la ~/alpine.wsl.gz
   # Should show read permissions for your user
   ```

3. **Windows Admin Rights**: Some operations need Windows admin privileges
   ```bash
   # Run PowerShell as administrator and try:
   wsl.exe --install --from-file "path\to\alpine.wsl.gz"
   ```

### First Boot Issues

If first boot fails or hangs:

1. **Terminate and Restart**: Sometimes a clean restart helps
   ```bash
   wsl.exe -t distribution-name
   wsl.exe -d distribution-name
   ```

2. **Check Logs**: Look for any error messages
   ```bash
   # In the distribution
   wsl.exe -d distribution-name -e cat /var/log/messages
   ```

3. **Manual First Boot Commands**: Try running the OOBE commands manually
   ```bash
   wsl.exe -d distribution-name -e ash /etc/oobe.sh
   ```

## Automated Testing Guide

For continuous integration or regular testing:

```bash
# Create a test script to run multiple tests in sequence
#!/usr/bin/env bash
set -e

# Test with different configurations
for alpine_version in edge v3.18 v3.17; do
  echo "Testing Alpine version: $alpine_version"
  
  # Create test environment
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  TEST_NAME="alp-test-${TIMESTAMP}"
  
  # Create test configuration
  cat > .env << EOF
  SUDO=sudo
  WSL_DISTRIBUTION_NAME=$TEST_NAME
  CHROOT_DIR="/tmp/$TEST_NAME"
  ALPINE_VERSION=$alpine_version
  EOF
  
  # Run build and test
  ./wsl-alpine-build.sh
  
  # Verify installation
  wsl.exe -d "$TEST_NAME" -e cat /etc/alpine-release
  
  # Clean up
  wsl.exe --unregister "$TEST_NAME"
  sudo rm -rf "/tmp/$TEST_NAME" 2>/dev/null || true
done
```

## After Testing

Always clean up test artifacts when finished:

```bash
# Run the cleanup script to remove all test distributions
./wsl-alpine-test-cleanup.sh

# Or manually clean up specific distributions
wsl.exe --unregister alp-test-TIMESTAMP 

# Remove temporary files
rm -f test.env build.log debug.log
sudo rm -rf /tmp/alp-test-* 2>/dev/null || true

# Check WSL distribution list to confirm removal
wsl.exe -l -v
```

## Test Matrix

When thoroughly testing the scripts, consider testing these combinations:

| Alpine Version | Package Preset | Systemd | Special Features |
|----------------|----------------|---------|-----------------|
| edge           | minimal        | false   | none            |
| v3.18          | standard       | false   | none            |
| v3.18          | development    | true    | custom packages |
| edge           | server         | true    | custom icon     |

This ensures compatibility across different configurations and use cases.