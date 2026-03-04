# WSL Alpine Build

A safe, modular system for building customized Alpine Linux distributions for Windows Subsystem for Linux (WSL). Builds are produced by `./wsl-alpine`, and day-to-day distro lifecycle/actions are run via `wsl.exe` directly.

## 🚀 Quick Start

```bash
# Build default distro (fast path: base,pi-agent)
./wsl-alpine build

# Build Alpine WSL with all features
./wsl-alpine build --modules all

# Or select specific modules
./wsl-alpine build --modules base,podman,pi-agent,development

# List available modules
./wsl-alpine module list
```

### Build with the script, run with `wsl.exe`

```bash
# Build + import with the project script
./wsl-alpine build --name alpine-dev --modules base,podman,pi-agent,development
```

```powershell
# Then use wsl.exe directly from Windows shells
wsl.exe -d alpine-dev
wsl.exe -d alpine-dev -- podman info
wsl.exe --terminate alpine-dev
```

## 📚 Docs (start here)

- Docs index (Diátaxis): [docs/README.md](docs/README.md)
- How-to: [Disposable Podman-first workspace](docs/how-to/disposable-workspace.md)
- Reference: [CLI reference](docs/reference/cli.md)
- Explanation: [Why WSL workspaces](docs/explanation/why-wsl-workspaces.md)

## 🎯 Overview

This project creates lightweight Alpine Linux WSL distributions using a modular approach. Unlike traditional methods that use dangerous chroot operations, we use Alpine's official minirootfs for a safer build process.

### Key Features

- **🔒 Safe Build Process** - No bind mounts or chroot operations required
- **📦 Modular System** - Pick and choose features through modules
- **🧪 Fully Tested** - Comprehensive test suite with BATS
- **🚀 Fast & Lightweight** - Minimal Alpine base with on-demand features
- **🔧 Easy Customization** - Add your own modules for specific needs

## 📋 Prerequisites

- **Environment**: WSL 1 or WSL 2 on Windows 10/11
- **Host OS**: Any Linux distribution running in WSL
- **Required Tools**:
  - `wget` - For downloading Alpine minirootfs
  - `tar` & `gzip` - For packaging
  - `fakeroot` - For preserving file permissions
  - Basic tools: `sha256sum`, `grep`, `sed`

## 🏗️ Available Modules

### Base Module (Required)
Essential Alpine system with WSL configuration
- Core Alpine packages
- WSL integration (wsl.conf)
- Default user setup (wsluser)
- OpenRC for service management

### Podman Module
Podman-first container tooling for WSL
- Podman and podman-remote
- Rootless-ready dependencies
- WSL-friendly container defaults
- Optimized for in-distro usage

### Development Module
Modern development tools and editors
- Helix editor with syntax highlighting
- Modern CLI tools (fd, bat, ripgrep, zoxide)
- Shell enhancements

### pi-agent Module
Installs the pi coding agent CLI used in this environment
- Node.js runtime
- @mariozechner/pi-coding-agent install helper
- Designed for direct use in the target WSL distro

## 🛠️ Usage

Use `./wsl-alpine` for build/packaging/import automation. Once imported, operate the distro with `wsl.exe` from CMD/PowerShell.

### Basic Commands

```bash
# Show help
./wsl-alpine help

# Build a distribution
./wsl-alpine build [options]

# Remove a distribution
./wsl-alpine reset <name>

# List distributions
./wsl-alpine list

# Run tests
./wsl-alpine test

# Run real end-to-end smoke test (build/import/verify)
./wsl-alpine test-smoke
```

### Build Options

```bash
./wsl-alpine build \
  --name my-alpine \           # Distribution name
  --modules base,podman,pi-agent \       # Modules to install
  --no-import                  # Build only, don't import
```

### Module Management

```bash
# List available modules
./wsl-alpine module list

# Get module information
./wsl-alpine module info podman
```

## 📝 Configuration

### Environment Variables

Create a `.env` file for persistent configuration:

```bash
# Distribution settings
WSL_DISTRIBUTION_NAME=alpine-wsl
ALPINE_VERSION=3.23.3
ALPINE_ARCH=x86_64

# Build settings
BUILD_DIR=/tmp/alpine-wsl-build
CACHE_DIR=$HOME/.cache/alpine-wsl

# Module selection (default)
DEFAULT_MODULES=base,pi-agent
```

### Custom Modules

Create your own modules in `src/modules/<name>/`:

1. Create module directory
2. Add `metadata.yaml` with module information
3. Add `install.sh` script for installation logic
4. Add `README.md` for documentation

Example structure:
```
src/modules/mymodule/
├── metadata.yaml
├── install.sh
└── README.md
```

## 🧪 Testing

The project includes comprehensive tests using BATS:

```bash
# Run standard test suite
./wsl-alpine test
```

## 🔄 Migration from Old Scripts

If you're using the previous version, see [MIGRATION.md](MIGRATION.md) for upgrade instructions.

Key differences:
- Single entry point (`wsl-alpine`) instead of multiple scripts
- Modular architecture instead of monolithic build
- Safer minirootfs approach instead of chroot operations
- Better error handling and testing

## 📚 Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) - Project requirements and design decisions
- [MIGRATION.md](MIGRATION.md) - Migration guide from old scripts
- [TESTING.md](TESTING.md) - Testing guide and troubleshooting
- [ADVANCED-WSL.md](ADVANCED-WSL.md) - Advanced WSL configuration
- [CLAUDE.md](CLAUDE.md) - AI assistance integration

## 🏛️ Architecture

```
wsl-alpine                    # Main entry point
├── src/lib/                  # Reusable libraries
│   ├── common.sh            # Common functions
│   ├── minirootfs.sh        # Minirootfs operations
│   ├── wsl-operations.sh    # WSL management
│   └── package.sh           # Package management
├── src/modules/              # Feature modules
│   ├── base/                # Core system
│   ├── podman/              # Container runtime (Podman)
│   ├── pi-agent/            # pi coding agent CLI
│   └── development/         # Dev tools
└── tests/                    # Test suite
    ├── unit/                # Unit tests
    └── integration/         # Integration tests
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is dual-licensed under MIT and Apache 2.0 licenses. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE) for details.

## 🙏 Acknowledgments

- Alpine Linux team for the excellent minimal distribution
- Microsoft WSL team for Linux on Windows
- The open source community for the amazing tools included

## ⚠️ Troubleshooting

### Common Issues

**Issue**: "wsl.exe not found"
- Ensure you're running from within WSL
- Try: `export PATH=$PATH:/mnt/c/Windows/System32`

**Issue**: "Permission denied"
- Some operations require sudo for system packages
- File permissions are preserved using fakeroot

**Issue**: "Module not found"
- Check available modules: `./wsl-alpine module list`
- Ensure module name is spelled correctly

For more issues, see [TESTING.md](TESTING.md) or open an issue on GitHub.