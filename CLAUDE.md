# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a safe, modular system for building customized Alpine Linux distributions for Windows Subsystem for Linux (WSL). The system has been completely refactored to use Alpine's official minirootfs instead of dangerous chroot operations.

## Current Architecture

### Main Entry Point
- `wsl-alpine` - Single command with subcommands for all operations
  - `build` - Build a new Alpine WSL distribution
  - `reset` - Remove a WSL distribution
  - `test` - Run test suite
  - `module` - Manage distribution modules
  - `list` - List WSL distributions

### Source Structure
```
src/
├── lib/                     # Reusable libraries
│   ├── common.sh           # Logging, error handling, utilities
│   ├── minirootfs.sh       # Alpine minirootfs operations
│   ├── wsl.sh              # WSL-specific operations
│   └── package.sh          # APK package management
└── modules/                 # Feature modules
    ├── base/               # Core Alpine system
    ├── docker/             # Docker container runtime
    ├── claude-code/        # Claude Code CLI integration
    └── development/        # Development tools
```

### Module System

Each module contains:
- `metadata.yaml` - Module information and dependencies
- `install.sh` - Installation script (sourced with ROOTFS_DIR set)
- `README.md` - Module documentation

Modules are applied sequentially during build. The base module is always required.

## Key Design Decisions

1. **Safety First**: No bind mounts or chroot operations. Uses fakeroot for packaging.
2. **Modular Architecture**: Features organized into independent modules.
3. **Comprehensive Testing**: Full test coverage with BATS framework.
4. **Clean Separation**: Libraries handle specific concerns (WSL, packages, etc.).
5. **Error Handling**: Consistent error handling with proper cleanup.

## Development Guidelines

### When Adding Features

1. **Determine Module Placement**:
   - System-level features → base module
   - Container features → docker module
   - Development tools → development module
   - New category → create new module

2. **Module Creation**:
   ```bash
   # Create module structure
   mkdir -p src/modules/mymodule
   
   # Create metadata
   cat > src/modules/mymodule/metadata.yaml << EOF
   name: mymodule
   version: 1.0.0
   description: My custom module
   dependencies: [base]
   packages:
     - package1
     - package2
   EOF
   
   # Create install script (see existing modules)
   ```

3. **Testing Requirements**:
   - Add unit tests for new library functions
   - Add integration tests for new commands
   - Ensure all tests pass: `./wsl-alpine test`

### Code Style

- Use `shellcheck` for all shell scripts
- Follow existing patterns in libraries
- Use consistent logging functions (log_info, log_error, etc.)
- Handle errors with proper cleanup
- Document functions with comments

### Common Tasks

**Building a Distribution**:
```bash
# Standard build with all modules
./wsl-alpine build --modules all

# Custom build
./wsl-alpine build --name my-alpine --modules base,docker
```

**Testing Changes**:
```bash
# Run all tests
./wsl-alpine test

# Run specific test file
bats tests/unit/test_common.bats

# Debug mode
DEBUG=1 ./wsl-alpine build --dry-run
```

**Adding Packages**:
1. Find appropriate module
2. Add to `packages:` list in metadata.yaml
3. Or add to install.sh for complex installation

## Important Files

### Configuration
- `.env` - Local environment configuration (not committed)
- `config/defaults.conf` - Default configuration values

### Documentation
- `README.md` - User-facing documentation
- `MIGRATION.md` - Migration guide from old system
- `TESTING.md` - Testing and troubleshooting guide
- `REQUIREMENTS.md` - Original project requirements

### Legacy
- `legacy/` - Deprecated scripts (reference only)

## Troubleshooting

### Build Failures
1. Check prerequisites: `check_dependencies wget tar gzip fakeroot`
2. Enable debug mode: `DEBUG=1 ./wsl-alpine build`
3. Check test results: `./wsl-alpine test`

### Module Issues
1. Verify module exists: `./wsl-alpine module list`
2. Check module info: `./wsl-alpine module info <name>`
3. Ensure dependencies are included

### WSL Issues
1. Ensure running from WSL environment
2. Check WSL executable: `which wsl.exe`
3. Add Windows paths if needed: `/mnt/c/Windows/System32`

## Claude Code Integration

The project includes a claude-code module that:
1. Installs Node.js and npm
2. Provides `install-claude-code` command
3. Includes Docker-aware wrapper
4. Sets up proper configuration

To use Claude Code after building:
```bash
# In the Alpine WSL distribution
install-claude-code
claude login
```

## Future Improvements

Potential areas for enhancement:
1. Module dependency resolution
2. Module versioning and updates
3. GUI module management tool
4. Cloud-based module repository
5. Automated testing in CI/CD

## Best Practices

1. **Always Test**: Run tests before committing changes
2. **Document Changes**: Update relevant documentation
3. **Maintain Compatibility**: Don't break existing functionality
4. **Keep It Simple**: Prefer clarity over cleverness
5. **Error Handling**: Always handle errors gracefully

When working with this codebase, prioritize safety, modularity, and maintainability.