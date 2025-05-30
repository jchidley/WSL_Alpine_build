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
   
   # Run the script (will auto-configure paths)
   sudo ./wsl-alpine-build.sh
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

## Claude Code Installation

After building your Alpine WSL distribution, you can install Claude Code for AI-powered coding assistance:

### Option 1: Manual Installation (Post-Build)

```bash
# Enter your Alpine WSL distribution
wsl.exe -d alp2

# Run the installation script
./wsl-alpine-claude-code.sh

# Or install in Docker for additional isolation
./wsl-alpine-claude-code.sh --docker
```

### Option 2: Automatic Installation (During Build)

Add to your `.env` file before building:

```bash
INSTALL_CLAUDE_CODE=true         # Install Claude Code during first boot
ANTHROPIC_API_KEY=sk-ant-...     # Optional: Pre-configure API key
```

### Authentication

Claude Code requires authentication via one of these methods:

1. **Claude Max Subscription**: Run `claude login` and follow the browser flow
2. **API Key**: Set `ANTHROPIC_API_KEY` environment variable

For more details, see the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code).

## Usage

### Starting Alpine Linux

After installation, you can start Alpine Linux with:

```bash
# Start as your user
wsl.exe -d alpine-wsl -u $USER --cd /home/$USER

# Or if you used a custom name
wsl.exe -d <distro-name> -u <username> --cd /home/<username>
```

### Running as Root

To run Alpine as root, you have several options:

#### 1. Direct root access:
```bash
wsl.exe -d alpine-wsl -u root --cd /
```

#### 2. From within Alpine as your user:
```bash
# Switch to root
sudo su -

# Or run a single command as root
sudo <command>
```

#### 3. Run a specific command as root:
```bash
wsl.exe -d alpine-wsl -u root --cd / -e <command>
```

#### 4. If you need to fix something before the user setup:
```bash
# Start as root directly
wsl.exe -d alpine-wsl -u root --cd /

# Then you can manually run the setup if needed
/root/setup-alpine-wsl.sh
```

Since the setup configures sudo access for the wheel group, your user can use `sudo` for administrative tasks, which is the recommended approach for security. But when you need direct root access (like for system recovery or initial setup), use the `-u root` option with wsl.exe.

## Testing

For testing without affecting your existing WSL setup:

```bash
# Run with automatic test name generation
./wsl-alpine-test.sh
```

## Cleanup

### Automated Cleanup

```bash
# Comprehensive cleanup with detailed scanning
sudo ./wsl-alpine-cleanup.sh

# Quick reset for default distribution
sudo ./wsl-alpine-reset.sh

# Clean up all test distributions
sudo ./wsl-alpine-test-cleanup.sh
```

### Manual Cleanup

See [CLEANUP-GUIDE.md](CLEANUP-GUIDE.md) for:
- Detailed cleanup instructions
- Troubleshooting cleanup issues
- Manual removal steps
- Windows-side cleanup

## Documentation

### Project Documentation
- See [REQUIREMENTS.md](REQUIREMENTS.md) for project rationale and requirements
- See [CLAUDE.md](CLAUDE.md) for project overview and AI guidance
- See [IMPROVEMENTS.md](IMPROVEMENTS.md) for implemented features and roadmap
- See [TESTING.md](TESTING.md) for detailed testing instructions
- See [ADVANCED-WSL.md](ADVANCED-WSL.md) for advanced WSL configuration and features
- See [CLEANUP-GUIDE.md](CLEANUP-GUIDE.md) for comprehensive cleanup instructions

### Related Articles
This project builds upon concepts detailed in these published articles:
- [Systems-on-Systems](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/) - Running systems within systems (WSL, Docker, VMs)
- [File Systems](https://jchidley.github.io/mkdocs-material-test/Linux/2020-01-28-FileSystems/) - Linux file systems including OverlayFS

## License

This project is dual-licensed under:
- [MIT License](LICENSE-MIT)
- [Apache License, Version 2.0](LICENSE-APACHE)