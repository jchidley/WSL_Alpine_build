# WSL Alpine Build

A comprehensive set of scripts to build a customized Alpine Linux distribution for Windows Subsystem for Linux (WSL).

## Overview

This project creates a lightweight, isolated Alpine Linux WSL distribution specifically designed for running Docker without the overhead of Docker Desktop. For detailed rationale and requirements, see [REQUIREMENTS.md](REQUIREMENTS.md).

### Key Features

- **Helix editor** with tree-sitter syntax highlighting for multiple languages
- **Docker** with lazydocker for container management
- **Terminal customization** with Gruvbox Dark theme
- **Modern command-line tools** (zoxide, fzf, bat, fd)
- **First-boot setup** for additional package installation

## Prerequisites

- **Host Environment**: A Linux distribution with WSL access (tested on Debian WSL)
- **Required Tools**:
  - `sudo` - for elevated permissions
  - `wget` - to download the alpine-chroot-install script
  - `sha1sum` - for verifying downloads
  - `tar` and `gzip` - for packaging the WSL distribution
  - `wsl.exe` - Windows Subsystem for Linux command (accessible from Linux)

## Quick Start

1. **Setup Configuration**
   ```bash
   # Create a .env file with basic configuration
   cat > .env << EOF
   SUDO=sudo
   WSL_DISTRIBUTION_NAME=alp2
   CHROOT_DIR="/tmp/alp2"
   EOF
   ```

2. **Run the Build Script**
   ```bash
   # Make sure the script is executable
   chmod +x wsl-alpine-build.sh
   
   # Run the script
   ./wsl-alpine-build.sh
   ```

3. **First Boot Setup**
   ```bash
   # Launch the new distribution
   wsl -d alp2
   
   # After first boot completes, restart the distribution
   wsl -t alp2 && wsl -d alp2
   ```

## Advanced Configuration

Create a `.env` file with additional options:

```bash
# Basic Configuration
SUDO=sudo
WSL_DISTRIBUTION_NAME=alp2
CHROOT_DIR="/tmp/alp2"

# Optional Configuration
ALPINE_VERSION=v3.18             # Specific Alpine version (default: edge)
EXTRA_PACKAGES="vim git curl"    # Additional packages to install
COMPRESSION_LEVEL=--best         # gzip compression level (default: --fast)
SYSTEMD_ENABLED=true             # Enable systemd (default: false)
```

## Testing

For testing without affecting your existing WSL setup:

```bash
# Run with automatic test name generation
./test-wsl-alpine-build.sh
```

## Cleanup

To remove a distribution:

```bash
# Use the reset script (reads from .env)
./reset-wsl-alpine-build.sh

# To clean up test distributions
./wsl-alpine-build-test-cleanup.sh
```

## Documentation

### Project Documentation
- See [REQUIREMENTS.md](REQUIREMENTS.md) for project rationale and requirements
- See [CLAUDE.md](CLAUDE.md) for project overview and AI guidance
- See [IMPROVEMENTS.md](IMPROVEMENTS.md) for implemented features and roadmap
- See [TESTING.md](TESTING.md) for detailed testing instructions
- See [ADVANCED-WSL.md](ADVANCED-WSL.md) for advanced WSL configuration and features

### Related Articles
This project builds upon concepts detailed in these published articles:
- [Systems-on-Systems](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/) - Running systems within systems (WSL, Docker, VMs)
- [File Systems](https://jchidley.github.io/mkdocs-material-test/Linux/2020-01-28-FileSystems/) - Linux file systems including OverlayFS

## License

This project is dual-licensed under:
- [MIT License](LICENSE-MIT)
- [Apache License, Version 2.0](LICENSE-APACHE)