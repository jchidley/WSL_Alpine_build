# Testing WSL Alpine Build Scripts

This document describes approaches for testing the WSL Alpine build scripts from within a WSL environment, with emphasis on safety and avoiding damage to existing WSL installations.

## ⚠️ SAFETY WARNINGS ⚠️

- **DISTRIBUTION NAME CONFLICTS**: Scripts may overwrite existing WSL distributions with the same name
- **BACKUP FIRST**: Always back up important WSL distributions before testing
- **USE UNIQUE TEST NAMES**: Always use unique distribution names with timestamps (e.g., "alp-test-20240520123045")
- **CHECK WSL LISTS**: Run `wsl.exe -l -v` before testing to see which distributions already exist
- **AVOID PRODUCTION SYSTEMS**: Do not test on systems where WSL is used for production work

## Prerequisites

- Windows 10/11 with WSL 2 enabled
- A WSL distribution (Debian, Ubuntu, etc.) installed and running
- Administrator privileges on Windows
- WSL interoperability (ability to run Windows executables from WSL)
- Required tools: `sudo`, `wget`, `sed`, `tar`, `gzip`

## Using the Test Script

The repository includes an enhanced `test-wsl-alpine-build.sh` script with several testing options:

### Test Options

1. **Standard Test**: Performs a complete build and verification
2. **Quick Test**: Only verifies WSL commands without building a distribution
3. **Advanced Test**: Allows customizing Alpine version and packages before testing
4. **Exit**: Cancels testing

### Running the Test Script

```bash
# Make the script executable
chmod +x test-wsl-alpine-build.sh

# Run the test script
./test-wsl-alpine-build.sh
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
   WSL_DISTRIBUTION_NAME=alp-test-$TIMESTAMP ./reset-wsl-alpine-build.sh
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
./wsl-alpine-build-test-cleanup.sh

# View all distributions but only remove test ones
./wsl-alpine-build-test-cleanup.sh --all

# Use a custom pattern for test distributions
./wsl-alpine-build-test-cleanup.sh --pattern "alpine-custom-.*"

# Get help on cleanup options
./wsl-alpine-build-test-cleanup.sh --help
```

## Debugging Tips

- **WSL Interoperability Check**:
  ```bash
  # Check WSL status and interoperability
  wsl.exe --status
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
  ```

- **Permission Issues**:
  ```bash
  # Check & fix permissions on chroot directory
  sudo chown -R $(id -u):$(id -g) "$CHROOT_DIR"
  ```

## After Testing

Always clean up test artifacts when finished:

```bash
# Unregister test distribution
wsl.exe --unregister alp-test-TIMESTAMP 

# Remove temporary files
rm -f test.env build.log debug.log
sudo rm -rf /tmp/alp-test-* 2>/dev/null || true
```