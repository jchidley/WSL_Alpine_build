# Migration Guide

This guide helps you migrate from the old Alpine WSL build scripts to the new modular system.

## Overview of Changes

The Alpine WSL build system has been completely refactored to be:
- **Safer**: Uses official Alpine minirootfs instead of chroot operations
- **Modular**: Features are organized into installable modules
- **Testable**: Comprehensive test coverage with BATS
- **Maintainable**: Clean architecture with reusable libraries

## Quick Migration

### Old Commands → New Commands

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `./wsl-alpine-build.sh` | `./wsl-alpine build` | Safer, modular approach |
| `./wsl-alpine-reset.sh` | `./wsl-alpine reset <name>` | Name is required |
| `./wsl-alpine-test.sh` | `./wsl-alpine test` | Integrated testing |
| `./wsl-alpine-test-cleanup.sh` | `./wsl-alpine test --cleanup` | Cleanup integrated |

### Configuration Changes

#### Old (.env file)
```bash
SUDO=sudo
WSL_DISTRIBUTION_NAME=alp2
CHROOT_DIR="/tmp/$WSL_DISTRIBUTION_NAME"
EDITOR_PACKAGES="helix vim"
TOOL_PACKAGES="fd bat zoxide"
```

#### New (.env file)
```bash
# Still supported for compatibility
WSL_DISTRIBUTION_NAME=alp2
ALPINE_VERSION=3.18.6

# New modular approach (recommended)
# Specify modules instead of individual packages
# Modules: base, docker, claude-code, development
```

### Build Process Changes

#### Old Approach
```bash
# Required sudo for chroot operations
sudo ./wsl-alpine-build.sh

# Packages specified in .env file
# All packages installed in one shot
```

#### New Approach
```bash
# No sudo required for build
./wsl-alpine build --modules base,docker,development

# Or build all modules
./wsl-alpine build --modules all

# Build without importing
./wsl-alpine build --no-import

# Import existing archive
./wsl-alpine build --import-only alpine-wsl.tar.gz
```

## Module System

Instead of specifying individual packages, the new system uses modules:

### Available Modules

1. **base** - Essential Alpine system
   - Core packages (alpine-base, openrc, sudo)
   - WSL configuration
   - Default user setup

2. **docker** - Container runtime
   - Docker Engine and CLI
   - Docker Compose
   - Lazydocker
   - WSL-optimized configuration

3. **claude-code** - AI development assistant
   - Node.js and npm
   - Claude Code CLI installer
   - Docker-aware configuration

4. **development** - Modern dev tools
   - Helix editor with syntax highlighting
   - Modern CLI tools (fd, bat, ripgrep, fzf)
   - Git, tmux, and programming languages

### Migrating Package Lists

If you had custom package lists in your .env file:

1. **Option 1**: Use existing modules
   ```bash
   # Most common packages are included in modules
   ./wsl-alpine build --modules all
   ```

2. **Option 2**: Create a custom module
   ```bash
   # Create src/modules/custom/
   mkdir -p src/modules/custom
   
   # Create metadata.yaml
   cat > src/modules/custom/metadata.yaml << EOF
   name: custom
   version: 1.0.0
   description: My custom packages
   dependencies: [base]
   packages:
     - package1
     - package2
   EOF
   
   # Create install.sh (see existing modules for examples)
   ```

## Step-by-Step Migration

### 1. Backup Existing Installation

```bash
# Export your current Alpine WSL
wsl --export alp2 alpine-backup.tar

# Or use the new tool
./wsl-alpine reset alp2 --preserve
```

### 2. Update Repository

```bash
# Pull latest changes
git pull

# Or clone fresh
git clone https://github.com/yourusername/WSL_Alpine_build.git
cd WSL_Alpine_build
```

### 3. Build New Distribution

```bash
# Basic build with all modules
./wsl-alpine build --name alpine-new --modules all

# Or select specific modules
./wsl-alpine build --name alpine-new --modules base,docker,development
```

### 4. Test New Distribution

```bash
# Start the new distribution
wsl -d alpine-new

# Verify your tools are installed
which docker
which hx  # Helix editor
which fd  # Modern find
```

### 5. Migrate Data (if needed)

```bash
# Copy files from old distribution
wsl -d alp2 -- tar -cf - /home/user/data | wsl -d alpine-new -- tar -xf - -C /
```

### 6. Remove Old Distribution

```bash
# Once satisfied with new installation
./wsl-alpine reset alp2
```

## Common Issues

### Issue: "command not found" errors

**Solution**: Make sure you selected the right modules. Check which module provides the command:
- Docker commands → `docker` module
- Helix editor → `development` module
- Claude CLI → `claude-code` module

### Issue: Different package names

**Solution**: The new system uses the same Alpine packages. If a specific package is missing:
1. Check if it's in another module: `./wsl-alpine module list`
2. Install it manually: `wsl -d alpine-new -- sudo apk add package-name`
3. Create a custom module for permanent inclusion

### Issue: Configuration differences

**Solution**: The new system creates configuration in standard locations:
- Helix: `~/.config/helix/config.toml`
- Git: `~/.gitconfig`
- Bash: `~/.bashrc`

## Advanced Migration

### Custom Build Scripts

If you had custom modifications to the build scripts:

1. **Identify the customizations**
   ```bash
   # Compare with original
   diff wsl-alpine-build.sh.backup legacy/wsl-alpine-build.sh
   ```

2. **Port to modules**
   - Package additions → Add to appropriate module
   - Configuration changes → Modify module install scripts
   - New features → Create new modules

### CI/CD Integration

The new system is more CI-friendly:

```yaml
# GitHub Actions example
- name: Build Alpine WSL
  run: |
    ./wsl-alpine build \
      --name alpine-ci \
      --modules base,development \
      --no-import \
      --dry-run  # Test build process
```

## Getting Help

1. **Check module documentation**
   ```bash
   ./wsl-alpine module info <module-name>
   ```

2. **Run tests to verify installation**
   ```bash
   ./wsl-alpine test
   ```

3. **Review the new documentation**
   - README.md - Updated usage instructions
   - CLAUDE.md - Integration with Claude Code
   - Module README files in src/modules/*/

## Rollback Plan

If you need to rollback:

1. **Restore from backup**
   ```bash
   wsl --import alp2 C:\WSL\alp2 alpine-backup.tar
   ```

2. **Use legacy scripts** (not recommended)
   ```bash
   cd legacy/
   sudo ./wsl-alpine-build.sh
   ```

Note: Legacy scripts are deprecated and may not work correctly with the new directory structure.

## Summary

The new modular system is:
- ✅ Safer (no dangerous chroot operations)
- ✅ More flexible (pick and choose modules)
- ✅ Better tested (comprehensive test suite)
- ✅ Easier to extend (just add modules)

Take time to explore the module system - it's designed to make Alpine WSL distributions more maintainable and customizable.