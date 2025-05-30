# Deprecated Scripts

This directory contains deprecated scripts that have been replaced by the new modular architecture.

## Migration Guide

The following scripts have been deprecated and replaced:

| Old Script | New Command | Notes |
|------------|-------------|-------|
| `wsl-alpine-build.sh` | `wsl-alpine build` | Uses safe minirootfs approach |
| `wsl-alpine-reset.sh` | `wsl-alpine reset` | Improved cleanup and safety |
| `wsl-alpine-test.sh` | `wsl-alpine test` | Better test isolation |
| `wsl-alpine-test-cleanup.sh` | `wsl-alpine test --cleanup` | Integrated into main script |
| `common-functions.sh` | `src/lib/common.sh` | Consolidated and improved |

## Why These Scripts Were Deprecated

1. **Safety Issues**: The old scripts used dangerous `alpine-chroot-install` which required bind mounts and elevated privileges
2. **Code Duplication**: Multiple scripts had redundant functions and inconsistent implementations
3. **Poor Modularity**: Hard to extend or modify functionality without breaking other parts
4. **Limited Testing**: No proper unit tests or integration tests

## Using the New System

The new system provides a single entry point with subcommands:

```bash
# Build a new Alpine WSL distribution
wsl-alpine build

# Build with specific modules
wsl-alpine build --modules base,docker,development

# Reset/remove a distribution
wsl-alpine reset alpine-wsl

# Run tests
wsl-alpine test

# Manage modules
wsl-alpine module list
wsl-alpine module install docker
```

## Important Notes

- These scripts are kept for reference only
- They may not work with the new directory structure
- For production use, please migrate to the new `wsl-alpine` command
- See MIGRATION.md in the root directory for detailed migration instructions