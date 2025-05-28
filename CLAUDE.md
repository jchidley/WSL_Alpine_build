# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains scripts for building a customized Alpine Linux distribution for Windows Subsystem for Linux (WSL). It uses Alpine's alpine-chroot-install script to create a lightweight Alpine installation with specific tools and configurations pre-installed.

## Repository Structure

- `wsl-alpine-build.sh` - Main script to build and install Alpine WSL distribution
- `wsl-alpine-reset.sh` - Script to unregister and clean up WSL distribution
- `wsl-alpine-test.sh` - Script for testing the build process with isolated test distributions
- `wsl-alpine-test-cleanup.sh` - Utility to clean up test distributions
- Documentation:
  - `README.md` - Main documentation with usage instructions
  - `REQUIREMENTS.md` - Project rationale, requirements, and design principles
  - `IMPROVEMENTS.md` - Implemented and future improvements
  - `TESTING.md` - Detailed testing instructions and troubleshooting
  - `ADVANCED-WSL.md` - Advanced WSL configuration and features
  - `CLAUDE.md` - This file, providing guidance for Claude Code

## Prerequisites

- **Host Environment**: A Linux distribution with WSL access (tested on Debian WSL)
- **Required Tools**:
  - `sudo` - for elevated permissions
  - `wget` - to download the alpine-chroot-install script
  - `sha1sum` - for verifying downloads
  - `tar` and `gzip` - for packaging the WSL distribution
  - `wsl.exe` - Windows Subsystem for Linux command (accessible from Linux)

## Configuration

Before running any scripts, create a `.env` file with these variables:
```
SUDO=sudo
WSL_DISTRIBUTION_NAME=alp2
CHROOT_DIR="/tmp/$WSL_DISTRIBUTION_NAME"
```

Optional variables include:
```
ALPINE_VERSION=v3.18            # Specific Alpine version
EDITOR_PACKAGES="helix vim"     # Editor packages to install
TOOL_PACKAGES="fd bat zoxide"   # Terminal utility packages
EXTRA_PACKAGES="git curl"       # Additional packages
COMPRESSION_LEVEL="--fast"      # gzip compression level
SYSTEMD_ENABLED=false           # Enable systemd support
WSL_INSTALL_PATH="$HOME/alpine.wsl.gz"  # Output file path
```

## Main Scripts

### wsl-alpine-build.sh

This script:
1. Downloads and validates the alpine-chroot-install script
2. Creates a minimal Alpine chroot with essential packages
3. Configures WSL-specific settings and terminal profiles
4. Adds a first-boot setup script (oobe.sh) for additional configuration
5. Bundles everything into a WSL-compatible archive
6. Installs the new distribution in WSL

### wsl-alpine-reset.sh

This script:
1. Unregisters the Alpine WSL distribution
2. Removes temporary files
3. Cleans up the chroot directory

### wsl-alpine-test.sh

This script:
1. Creates a uniquely named test distribution
2. Offers different test modes (standard, quick, advanced)
3. Verifies the installation works properly
4. Provides cleanup options

### wsl-alpine-test-cleanup.sh

This script:
1. Identifies test distributions based on naming pattern
2. Safely unregisters test distributions
3. Cleans up associated files and directories

## Workflow

1. Create the `.env` file with your preferred configuration
2. Run `./wsl-alpine-build.sh` to build and install the Alpine WSL distribution
3. After first boot, follow the on-screen instructions to complete installation
4. If needed, run `./wsl-alpine-reset.sh` to clean up and remove the distribution

## Custom Configurations

The build process includes several customizations:
- Helix editor with tree-sitter syntax highlighting for multiple languages
- Docker with lazydocker for container management
- Terminal styling with Gruvbox Dark theme
- zoxide, fzf, bat, and fd for improved terminal experience
- First-boot setup script for additional package installation

## Testing and Development

When developing new features:
1. Use the test script to create isolated test distributions
2. Add configuration options in the `.env` file and set defaults in the script
3. Follow the error handling and safety patterns in existing code
4. Add appropriate progress indicators and user feedback
5. Document changes in the appropriate markdown files
6. Update this file if necessary for Claude Code guidance

## Troubleshooting

- If the script fails with permission errors, verify sudo access
- If WSL commands fail, ensure you're running from a proper WSL environment with Windows access
- The generated distribution file is created at `~/alpine.wsl.gz`
- See TESTING.md for detailed troubleshooting guidance