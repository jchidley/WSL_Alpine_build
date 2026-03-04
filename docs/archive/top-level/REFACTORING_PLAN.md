# Alpine WSL Minirootfs Refactoring Plan - Immediate Implementation

## Executive Summary

This plan outlines the immediate refactoring of the Alpine WSL build system to:
1. Fully adopt the safe minirootfs approach
2. Eliminate redundant code and deprecated scripts
3. Create a clean, modular architecture
4. Maintain comprehensive BATS testing
5. Ensure backwards compatibility where needed

**Timeline: Immediate implementation with Claude Code - all phases executed concurrently**

## Current State Analysis

### Problems Identified
1. **Three different build approaches** coexist (alpine-chroot-install, modular, minirootfs)
2. **Duplicate logging systems** (emoji-based vs color-based)
3. **Redundant libraries** (common-functions.sh vs src/lib/common.sh)
4. **Deprecated scripts** still using dangerous alpine-chroot-install
5. **Limited test coverage** - only 3 scripts have tests
6. **Inconsistent error handling** across scripts

### Assets to Preserve
1. Modular architecture in `src/lib/` and `modules/`
2. BATS test framework and existing tests
3. Comprehensive documentation
4. Working minirootfs implementation
5. Claude Code integration modules

## Proposed Architecture

```
WSL_Alpine_build/
├── wsl-alpine                  # Main executable (new)
├── src/
│   ├── lib/
│   │   ├── common.sh          # Unified logging, error handling
│   │   ├── prerequisites.sh   # Dependency checking
│   │   ├── minirootfs.sh      # Core build functions (new)
│   │   ├── wsl.sh             # WSL operations (new)
│   │   └── package.sh         # Package management (new)
│   └── modules/
│       ├── base/              # Base system module
│       ├── docker/            # Docker installation
│       ├── claude-code/       # Claude Code integration
│       └── development/       # Dev tools (helix, etc.)
├── tests/
│   ├── unit/                  # Unit tests for all libs
│   ├── integration/           # Integration tests
│   ├── fixtures/              # Test data
│   └── mocks/                 # Mock implementations
├── config/
│   └── defaults.conf          # Default configuration
└── legacy/                    # Deprecated scripts (archive)
```

## Phase 1: Foundation (Immediate)

### 1.1 Consolidate Libraries
- [ ] Merge common-functions.sh and src/lib/common.sh
- [ ] Standardize on color-based logging (more professional)
- [ ] Create unified error handling with proper exit codes
- [ ] Add debug mode support (`DEBUG=1`)

### 1.2 Create Core Libraries
- [ ] Extract minirootfs operations into src/lib/minirootfs.sh
- [ ] Create src/lib/wsl.sh for all WSL operations
- [ ] Create src/lib/package.sh for APK package management
- [ ] Ensure all libraries are thoroughly documented

### 1.3 Archive Deprecated Scripts
- [ ] Move alpine-chroot-install scripts to legacy/
- [ ] Add deprecation notices
- [ ] Update documentation to point to new approach

## Phase 2: Modular Build System (Concurrent)

### 2.1 Module Structure
Each module will have:
```
modules/<name>/
├── metadata.yaml       # Name, version, dependencies
├── install.sh         # Installation script
├── configure.sh       # Configuration script
├── test.bats         # Module-specific tests
└── README.md         # Module documentation
```

### 2.2 Core Modules

#### Base Module (modules/base/)
- Minimal Alpine setup
- WSL configuration (wsl.conf)
- User creation
- Basic utilities

#### Docker Module (modules/docker/)
- Docker daemon installation
- Docker Compose
- Lazydocker
- OpenRC service configuration

#### Claude Code Module (modules/claude-code/)
- Node.js installation
- Claude Code CLI
- Optional Docker container setup

#### Development Module (modules/development/)
- Helix editor with themes
- Modern CLI tools (bat, fd, fzf, zoxide)
- Git configuration

### 2.3 Module Manager
Create a simple module manager in the main script:
```bash
wsl-alpine module list          # List available modules
wsl-alpine module install docker # Install specific module
wsl-alpine module remove docker  # Remove module
```

## Phase 3: Main Script Refactor (Concurrent)

### 3.1 New Main Script: `wsl-alpine`
Single entry point with subcommands:
```bash
wsl-alpine build [options]      # Build distribution
wsl-alpine install [options]    # Import into WSL
wsl-alpine reset <name>         # Remove distribution
wsl-alpine test [options]       # Run tests
wsl-alpine module <command>     # Module management
```

### 3.2 Build Process
1. Download and verify minirootfs
2. Extract to build directory
3. Apply base module
4. Apply selected additional modules
5. Package with fakeroot
6. Optionally import to WSL

### 3.3 Configuration
- Use config/defaults.conf for defaults
- Support .env file overrides
- Command-line arguments take precedence

## Phase 4: Testing (Parallel Development)

### 4.1 Test Coverage Goals
- 100% coverage for src/lib/*.sh
- Integration tests for each module
- End-to-end tests for main workflows

### 4.2 New Tests to Create
```
tests/unit/
├── test_minirootfs.bats
├── test_wsl.bats
├── test_package.bats
└── test_common_unified.bats

tests/integration/
├── test_build_process.bats
├── test_module_install.bats
└── test_full_workflow.bats
```

### 4.3 Test Infrastructure
- Mock WSL commands for CI testing
- Use Docker for isolated test environments
- Add GitHub Actions for automated testing

## Phase 5: Documentation and Migration (Throughout)

### 5.1 Documentation Updates
- [ ] Update README.md with new architecture
- [ ] Create MIGRATION.md for users of old scripts
- [ ] Update CLAUDE.md with new patterns
- [ ] Add module development guide

### 5.2 Migration Support
- [ ] Create migration script for existing installations
- [ ] Provide compatibility shims if needed
- [ ] Clear upgrade path documentation

## Implementation Order

Since we're using Claude Code for immediate implementation, we'll execute tasks in this optimized order:

### Step 1: Create Directory Structure (5 minutes)
```bash
mkdir -p src/lib src/modules/{base,docker,claude-code,development} 
mkdir -p tests/{unit,integration,fixtures,mocks} config legacy
```

### Step 2: Library Consolidation (30 minutes)
1. Merge common-functions.sh + src/lib/common.sh → unified src/lib/common.sh
2. Extract minirootfs functions → src/lib/minirootfs.sh
3. Extract WSL operations → src/lib/wsl.sh
4. Create package management → src/lib/package.sh

### Step 3: Archive Deprecated Scripts (10 minutes)
Move all alpine-chroot-install based scripts to legacy/ with deprecation notices

### Step 4: Create Main Script (45 minutes)
Build `wsl-alpine` with subcommands for build, install, reset, test, and module management

### Step 5: Implement Modules (1 hour)
Create module structure with install.sh, configure.sh, and metadata.yaml for each:
- base: Core Alpine setup
- docker: Docker + compose + lazydocker
- claude-code: Node.js + Claude Code CLI
- development: Helix + modern CLI tools

### Step 6: Write Tests (45 minutes)
Create BATS tests for all libraries and integration tests for workflows

### Step 7: Documentation Updates (30 minutes)
Update README.md, create MIGRATION.md, update CLAUDE.md

**Total Time: ~4 hours of focused implementation**

## Success Criteria

1. **Safety**: No bind mounts or chroot operations
2. **Modularity**: Easy to add/remove features
3. **Testing**: >80% code coverage
4. **Performance**: Build time <2 minutes
5. **Usability**: Single command installation
6. **Maintainability**: Clear code structure, comprehensive docs

## Risk Mitigation

1. **Breaking Changes**: Keep legacy scripts available in archive
2. **User Migration**: Provide clear migration guide and tools
3. **Module Dependencies**: Implement proper dependency resolution
4. **Testing Complexity**: Start with critical path tests first

## Next Steps

1. Create feature branch: `refactor/minirootfs-modular`
2. Execute all implementation steps immediately
3. Test the refactored system
4. Merge to main branch

## Implementation Checklist

- [ ] Create directory structure
- [ ] Consolidate libraries
- [ ] Archive deprecated scripts
- [ ] Implement main `wsl-alpine` script
- [ ] Create all modules (base, docker, claude-code, development)
- [ ] Write comprehensive BATS tests
- [ ] Update documentation
- [ ] Test full build process
- [ ] Create migration guide
- [ ] Final review and merge

This immediate refactoring will result in a safer, more maintainable, and more flexible Alpine WSL build system that follows best practices and modern development standards.