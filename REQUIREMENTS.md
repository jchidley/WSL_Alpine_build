# Requirements and Rationale

## Project Background

This project was created to address specific limitations and concerns with the standard Docker installation approach on Windows, which typically involves:

1. **Docker Desktop** - A heavyweight solution that creates its own WSL2 distribution
2. **Additional overhead** - Docker Desktop includes many features and services that may not be needed
3. **System pollution** - Installing Docker in the primary working WSL distribution (e.g., Debian) adds complexity and potential conflicts
4. **Resource consumption** - Docker Desktop's approach can be resource-intensive

## Solution Approach

The solution is to create a dedicated, minimal WSL distribution specifically for running Docker and other containerized workloads, keeping it separate from the primary development environment.

## Why Alpine Linux?

Alpine Linux was chosen as the base distribution for several compelling reasons:

### 1. **Minimal Footprint**
- Base installation is extremely small (~5MB)
- Uses musl libc instead of glibc, reducing size
- Minimal default packages mean less attack surface

### 2. **Container-Focused Design**
- Alpine is the de facto standard for container base images
- Designed with containers and virtualization in mind
- Efficient resource usage makes it ideal for WSL

### 3. **Excellent Package Management**
- APK (Alpine Package Keeper) is fast and efficient
- Extensive package repository with good maintenance
- Simple package format and dependency resolution

### 4. **Strong Security**
- Security-oriented design with PIE (Position Independent Executables)
- Proactive security features enabled by default
- Regular security updates

### 5. **Wide Industry Adoption**
- Used extensively in production environments
- Well-documented with active community support
- Battle-tested in containerized workloads

### 6. **OpenRC Init System**
- Lightweight alternative to systemd
- Perfect for WSL where full systemd support can be problematic
- Simple and predictable service management

## Core Requirements

### Functional Requirements

1. **Isolated Docker Environment**
   - Docker must run in a separate WSL distribution
   - No interference with primary development WSL distribution
   - Easy to reset or rebuild without affecting other work

2. **Minimal Resource Usage**
   - Small disk footprint
   - Low memory consumption when idle
   - Quick startup and shutdown times

3. **Developer Tools**
   - Modern text editor (Helix) with syntax highlighting
   - Essential command-line tools (git, curl, wget)
   - Terminal enhancements (bat, fd, fzf, zoxide)

4. **Easy Management**
   - Simple installation process
   - Clear configuration through environment variables
   - Straightforward upgrade and removal procedures

### Technical Requirements

1. **WSL2 Compatibility**
   - Must work with WSL2 on Windows 10/11
   - Support for WSL interop features
   - Proper networking with Windows host

2. **Docker Support**
   - Native Docker daemon support
   - Docker Compose functionality
   - Optional rootless Docker mode

3. **Reproducible Builds**
   - Scripted installation process
   - Version-controlled configuration
   - Consistent results across installations

4. **Customization Options**
   - Configurable package selection
   - Optional features (systemd, USB support)
   - Extensible through environment variables

## Use Cases

### Primary Use Case: Docker Development
- Run Docker containers without Docker Desktop
- Keep Docker isolated from main development environment
- Easy cleanup and recreation of Docker environment

### Secondary Use Cases
1. **Testing Alpine-based Applications**
   - Test software that will run on Alpine in production
   - Verify compatibility with musl libc

2. **Lightweight Development Environment**
   - Quick spin-up of temporary development environments
   - Minimal resource usage for resource-constrained systems

3. **Container Building**
   - Build and test Alpine-based container images
   - Understand Alpine-specific requirements and limitations

4. **Learning and Experimentation**
   - Learn about WSL2 distribution creation
   - Experiment with Alpine Linux features
   - Understand minimal Linux distributions

## Design Principles

1. **Separation of Concerns**
   - Docker runs in its own WSL distribution
   - Main development environment remains clean
   - Easy to remove or rebuild without side effects

2. **Minimal by Default**
   - Start with the smallest viable system
   - Add only what's necessary
   - User can extend as needed

3. **Automation First**
   - Fully scripted installation
   - No manual steps required
   - Reproducible and version-controlled

4. **Developer Friendly**
   - Include modern developer tools
   - Good terminal experience out of the box
   - Easy to customize and extend

5. **WSL Best Practices**
   - Proper WSL configuration files
   - Respect WSL conventions
   - Good Windows/Linux interoperability

## Non-Requirements

This project explicitly does NOT aim to:

1. Replace Docker Desktop for all use cases
2. Provide a full desktop environment
3. Support every possible Docker configuration
4. Compete with full Linux distributions
5. Provide production-ready security hardening

## Success Criteria

The project is considered successful when:

1. Docker runs reliably in an isolated Alpine WSL distribution
2. The distribution uses minimal resources (< 1GB disk, < 256MB RAM idle)
3. Installation is automated and takes < 5 minutes
4. The environment can be completely removed without traces
5. Common Docker workflows function correctly
6. The solution is maintainable and well-documented

## Comprehensive Requirements List

This section compiles all requirements that are explicitly stated or can be directly inferred from the project documentation and linked resources.

### System Requirements

1. **Host Operating System**
   - Windows 10 version 1903 or higher with Build 18362 or higher
   - Windows 11 (any version)
   - WSL 2 enabled and configured

2. **WSL Requirements**
   - WSL version 1.2.5.0 or higher (for `--from-file` support)
   - WSL 2 kernel 5.10.60.1 or later (for USB device support)
   - WSL interoperability enabled (ability to run Windows executables from Linux)

3. **Host WSL Distribution Requirements**
   - A Linux distribution running in WSL (tested on Debian)
   - Required tools installed:
     - `sudo` - for elevated permissions
     - `wget` - to download the alpine-chroot-install script
     - `sha1sum` - for verifying downloads
     - `tar` and `gzip` - for packaging the WSL distribution
     - `bash` - for running the scripts
     - `sed` - for text processing
   - Access to `wsl.exe` command from within WSL
   - Internet connectivity for downloading Alpine packages

4. **Disk Space Requirements**
   - Minimum 1GB free space for building the distribution
   - Additional space for Docker images and containers
   - Temporary space in `/tmp` for build process

### Build Process Requirements

5. **Alpine Linux Requirements**
   - Alpine Linux edge or specific version (configurable)
   - Access to Alpine package repositories
   - alpine-chroot-install script from GitHub

6. **Package Requirements**
   - Core packages:
     - `openrc` - init system
     - `openrc-settingsd` - OpenRC settings daemon
     - `util-linux-misc` - various system utilities
   - Editor packages (configurable):
     - `helix` - primary text editor
     - Tree-sitter grammars for syntax highlighting
   - Development tools:
     - `git` - version control
     - `curl` - data transfer tool
     - `wget` - network downloader
   - Terminal enhancements:
     - `zoxide` - smarter cd command
     - `fzf` - fuzzy finder
     - `bat` - cat with syntax highlighting
     - `fd` - find alternative
   - Docker packages:
     - `docker` - container runtime
     - `docker-cli` - Docker command line
     - `docker-compose` - multi-container applications
     - `lazydocker` - terminal UI for Docker

7. **Configuration Requirements**
   - Environment variable configuration via `.env` file
   - Support for customizable:
     - Distribution name
     - Alpine version
     - Package selection
     - Compression level
     - Installation path

### Runtime Requirements

8. **WSL Distribution Configuration**
   - Proper `/etc/wsl.conf` configuration:
     - Boot commands for starting services
     - Automount settings for Windows drives
     - Network configuration
     - User settings
   - Windows Terminal profile generation

9. **Service Management Requirements**
   - OpenRC configured as init system
   - Docker service configured to start on boot (optional)
   - udev service for USB device support (optional)

10. **File System Requirements**
    - Read-write root filesystem
    - Proper permissions for Docker socket
    - Access to Windows filesystem via `/mnt/`

### Security Requirements

11. **Permission Requirements**
    - Script runs with sudo privileges during build
    - Distribution can run as non-root user (configurable)
    - Docker socket permissions properly configured

12. **Network Security**
    - WSL shares network namespace with Windows host
    - No additional ports exposed by default
    - Docker networking follows standard Docker security model

### Testing Requirements

13. **Test Environment Requirements**
    - Ability to create uniquely named test distributions
    - Automatic cleanup of test distributions
    - Non-destructive testing (won't affect existing distributions)

14. **Verification Requirements**
    - Distribution appears in `wsl.exe -l -v` output
    - Basic commands execute successfully
    - Alpine version can be verified
    - Installed packages can be listed
    - Docker daemon starts and runs

### User Experience Requirements

15. **Installation Experience**
    - Clear progress indicators with emoji markers
    - Helpful error messages
    - Automatic creation of default configuration if missing
    - Post-installation instructions

16. **First Boot Experience**
    - Automated package installation on first boot
    - Clear instructions for next steps
    - Proper terminal configuration (Gruvbox theme)

17. **Cleanup Experience**
    - Safe uninstallation with confirmation prompts
    - Complete removal of all artifacts
    - Clear indication of what will be removed

### Documentation Requirements

18. **Project Documentation**
    - Clear README with quick start guide
    - Detailed requirements documentation
    - Testing procedures and troubleshooting
    - Advanced configuration options
    - AI/Claude Code guidance

19. **Script Documentation**
    - Clear header comments in scripts
    - Inline comments for complex operations
    - Help text for command-line options

### Maintenance Requirements

20. **Version Control**
    - All scripts and documentation in Git
    - Proper licensing (dual MIT/Apache)
    - Copyright information

21. **Extensibility Requirements**
    - Easy to add new packages
    - Configuration through environment variables
    - Modular script design
    - Clear patterns for customization

### Advanced Feature Requirements (Optional)

22. **USB Device Support**
    - usbipd integration capability
    - udev rules management
    - Proper device permissions

23. **Custom Kernel Support**
    - Ability to use custom WSL kernel
    - Kernel command line configuration

24. **Rootless Docker Support**
    - Optional rootless Docker configuration
    - Proper user namespace setup

25. **Overlay Filesystem Support**
    - Optional read-only root with overlay
    - Persistent storage configuration

### Future Modular System Requirements

26. **Modular Build Architecture**
    - Separation of base system from optional components
    - Module-based installation system
    - Clear module interfaces and dependencies

27. **Minimal Base System**
    - Core Alpine Linux without Docker
    - Essential development tools only:
      - Helix editor with syntax highlighting
      - Terminal enhancements (bat, fd, fzf, zoxide)
      - Git and basic utilities
    - Minimal resource footprint (< 500MB disk)

28. **Docker Module Package**
    - Standalone installation package for Docker
    - Installation script that:
      - Installs Docker, Docker CLI, Docker Compose
      - Configures OpenRC service
      - Sets up proper permissions
      - Installs lazydocker
    - Configuration script for Docker settings
    - Uninstall capability

29. **Claude Desktop Module Package**
    - Standalone installation package for Claude Desktop
    - Prerequisites check (X11, dependencies)
    - Installation script that:
      - Installs Claude Desktop application
      - Configures desktop integration
      - Sets up necessary permissions
    - Configuration for WSL GUI support
    - Uninstall capability

30. **Claude Code Module Package**
    - Standalone installation package for Claude Code
    - Docker Dev Container configuration based on Anthropic's reference implementation
    - Automated setup that:
      - Installs Claude Code CLI tool
      - Creates Docker Dev Container with Node.js 20
      - Configures network isolation (default-deny firewall policy)
      - Sets up development tools (git, ZSH)
      - Mounts project directories with proper permissions
      - Enables safe use of `--dangerously-skip-permissions` flag
    - Integration with VS Code Remote - Containers (optional)
    - Preconfigured security settings for isolated execution
    - Support for running without internet access
    - Automated container lifecycle management

31. **Module Management System**
    - Module registry/catalog functionality
    - Dependency resolution between modules
    - Module versioning support
    - Module enable/disable functionality
    - Module update mechanism

32. **Module Development Requirements**
    - Standardized module structure
    - Module manifest format (name, version, dependencies)
    - Installation/uninstallation hooks
    - Configuration templates
    - Testing framework for modules

## Implementation Status and Roadmap

This section tracks the implementation status of requirements. For detailed implementation notes with code examples, see [IMPROVEMENTS.md](IMPROVEMENTS.md).

### Version 1.0 (Implemented) ✅

Implementation Date: 2025-05-20

- [x] REQ-1: Basic Alpine WSL distribution creation
- [x] REQ-2: WSL command checking and validation
- [x] REQ-3: Windows path handling utilities
- [x] REQ-4: Docker installation and configuration
- [x] REQ-5: Helix editor with syntax highlighting
- [x] REQ-6: Terminal enhancements (bat, fd, fzf, zoxide)
- [x] REQ-7: First-boot setup script (oobe.sh)
- [x] REQ-8: Configuration via .env file
- [x] REQ-9: Alpine version configuration
- [x] REQ-10: Package customization groups
- [x] REQ-11: Test script with multiple test modes
- [x] REQ-12: Test cleanup utilities
- [x] REQ-13: Progress indicators with emoji
- [x] REQ-14: Error handling with set -e
- [x] REQ-15: Distribution conflict detection
- [x] REQ-16: Reset script with safety checks
- [x] REQ-17: Installation verification
- [x] REQ-18: Windows Terminal profile generation
- [x] REQ-19: Post-installation instructions
- [x] REQ-20: Default .env file creation

### Version 1.1 (Planned) 🚧

Requirements Proposed: 2025-05-28

- [ ] REQ-21: User account creation during installation
- [ ] REQ-22: Package presets (minimal, development, server)
- [ ] REQ-23: Custom icon support for WSL distribution
- [ ] REQ-24: Systemd support option
- [ ] REQ-25: Post-installation customization hooks
- [ ] REQ-26: Export/Import configuration

### Version 2.0 (Planned - Modular System) 📋

Requirements Proposed: 2025-05-28

- [ ] REQ-27: Modular build architecture
- [ ] REQ-28: Minimal base system (without Docker)
- [ ] REQ-29: Docker module package
- [ ] REQ-30: Claude Desktop module package
- [ ] REQ-31: Claude Code module package (with Docker Dev Container)
- [ ] REQ-32: Module management system
- [ ] REQ-33: Module development framework
- [ ] REQ-34: Module registry/catalog
- [ ] REQ-35: Module dependency resolution

### Version 2.1 (Planned - Advanced Features) 📋

Requirements Source: Systems-on-Systems article (2023-09-24) and FileSystems article (2020-01-28)

- [ ] REQ-36: USB device support with usbipd (from Systems-on-Systems)
- [ ] REQ-37: Rootless Docker option (from Systems-on-Systems)
- [ ] REQ-38: Overlay filesystem support (from FileSystems)
- [ ] REQ-39: Custom kernel support (from Systems-on-Systems)
- [ ] REQ-40: Advanced network configuration
- [ ] REQ-41: Development environment presets (Python, Rust, etc.)
- [ ] REQ-42: Shared directory configuration

### Version 3.0 (Future - Enterprise) 🔮

Requirements Proposed: 2025-05-28

- [ ] REQ-43: Multi-distribution management
- [ ] REQ-44: Backup and restore functionality
- [ ] REQ-45: Distribution templates
- [ ] REQ-46: Automated updates
- [ ] REQ-47: Security hardening options
- [ ] REQ-48: Distribution upgrade path
- [ ] REQ-49: Integration with CI/CD pipelines

### Additional Requirements (Added Post-Implementation)

Requirements Added: 2025-05-28

- [x] REQ-50: Automatic PATH configuration for Windows executables under sudo
  - Scripts should automatically detect when running under sudo without Windows paths
  - Attempt to add common Windows paths to PATH automatically
  - Only require `sudo -E` as a fallback if automatic configuration fails
  - Implemented via common-functions.sh shared by all scripts

Requirements Added: 2025-05-29

- [ ] REQ-51: Claude Code installation script for Alpine WSL distribution
  - Priority: Medium
  - Status: Proposed
  - GitHub Issue: TBD
  - Description: Create a script within WSL_Alpine_build project to install Claude Code inside a newly built Alpine WSL distribution
  - Rationale: Enables users to easily add Claude Code to their Alpine WSL environment, providing AI-powered coding assistance within the isolated Alpine distribution
  - Implementation Notes:
    - Script should be part of the WSL_Alpine_build project (e.g., wsl-alpine-claude-code.sh)
    - Install Claude Code using npm inside the Alpine WSL distribution
    - Handle Node.js installation if not present in Alpine
    - Configure proper permissions and environment variables
    - Option to run Claude Code in Docker container within Alpine WSL for additional isolation
    - Integration with existing Alpine WSL build process (could be optional module or post-install script)

- [ ] REQ-52: Windows Terminal profile management for WSL distributions
  - Priority: Medium
  - Status: Proposed
  - GitHub Issue: TBD
  - Description: Automatically add WSL distributions to Windows Terminal profiles when created and remove them when cleaned up
  - Rationale: Improves user experience by ensuring Windows Terminal always shows current WSL distributions without manual configuration
  - Implementation Notes:
    - Add function to create Windows Terminal profile during WSL import
    - Add function to remove Windows Terminal profile during WSL unregister
    - Profile should include custom name, icon, and color scheme
    - Handle both stable and preview versions of Windows Terminal
    - Store profile GUID for reliable removal during cleanup
    - Support for both JSON and new settings UI formats

- [ ] REQ-53: Comprehensive test suite for all scripts
  - Priority: High
  - Status: Proposed
  - GitHub Issue: TBD
  - Description: Create a comprehensive test suite that validates all scripts and their functions work correctly
  - Rationale: Ensures reliability and prevents regressions as the codebase evolves, especially important after the recent refactoring to use common functions
  - Implementation Notes:
    - Create test framework using bash test tools (bats or similar)
    - Test common-functions.sh thoroughly as it's the foundation for all scripts
    - Unit tests for individual functions (logging, config loading, WSL operations)
    - Integration tests for full script workflows (build, reset, test, cleanup)
    - Mock WSL commands to enable testing without actual WSL environment
    - Test error handling and edge cases (missing files, permission issues, etc.)
    - Automated test execution in CI/CD pipeline
    - Coverage reporting to identify untested code paths
    - Performance tests for build process optimization
    - Test matrix for different Alpine versions and configurations

- [ ] REQ-54: Complete refactoring of all scripts to eliminate redundancy
  - Priority: High
  - Status: In Progress
  - GitHub Issue: TBD
  - Description: Refactor all scripts to use common-functions.sh and eliminate code duplication and obsolete code
  - Rationale: Improves maintainability, reduces bugs from inconsistent implementations, and makes the codebase easier to understand and modify
  - Implementation Notes:
    - Continue refactoring remaining scripts (build, test, cleanup) to use common-functions.sh
    - Remove all duplicated code blocks identified in code audit
    - Eliminate obsolete code and commented-out sections
    - Standardize error handling patterns across all scripts
    - Consolidate WSL operations using shared functions
    - Unify logging and output formatting
    - Remove redundant PATH handling code
    - Consolidate configuration loading logic
    - Standardize cleanup operations
    - Ensure consistent use of constants and naming conventions
    - Update all scripts to follow the same structural pattern
    - Document any script-specific functions that remain

- [ ] REQ-55: Replace alpine-chroot-install with safe minirootfs approach
  - Priority: Critical
  - Status: In Progress
  - GitHub Issue: #33
  - Description: Replace the current alpine-chroot-install based build process with Alpine's official minirootfs approach to eliminate host system corruption risks
  - Rationale: The alpine-chroot-install tool creates dangerous bind mounts (/dev, /proc, /sys) that can corrupt the host system if cleanup fails. This has already caused deletion of critical devices (/dev/null, /dev/random, /dev/urandom) during development.
  - Implementation Notes:
    - Use Alpine's official minirootfs tarballs as the base
    - No bind mounts or chroot operations required
    - Direct file manipulation for configuration
    - APK package installation using --root flag
    - Follows Microsoft's WSL distribution guidelines
    - Creates proper wsl.conf and wsl-distribution.conf files
    - Implements OOBE (Out-of-Box Experience) script
    - Maintains all existing functionality (Docker, Helix, modern CLI tools)
    - Simpler, safer, and more maintainable approach
    - Already fully documented in MINIROOTFS-APPROACH.md

- [ ] REQ-56: Refactor scripts for MINIROOTFS-APPROACH implementation
  - Priority: Critical
  - Status: Proposed
  - GitHub Issue: TBD
  - Description: Refactor the scripts to implement the minirootfs approach as documented in MINIROOTFS-APPROACH.md
  - Rationale: The current scripts still use the dangerous alpine-chroot-install approach. Need to refactor them to use the safer minirootfs approach that has been thoroughly tested and documented.
  - Implementation Notes:
    - Refactor wsl-alpine-build.sh to use minirootfs approach
    - Update all related scripts to work with the new approach
    - Remove all dependencies on alpine-chroot-install
    - Implement the safe build process without bind mounts
    - Use the lessons learned from MINIROOTFS-APPROACH.md
    - Ensure modular design for Claude Code and other optional components
    - Test thoroughly to avoid the issues documented in failure analysis

- [ ] REQ-57: Handle init system limitations with automatic startup scripts
  - Priority: High
  - Status: Proposed
  - GitHub Issue: TBD
  - Description: systemd/OpenRC doesn't work as expected on WSL/Linux but often the same needs can be met with automatic startup scripts
  - Rationale: WSL doesn't fully support traditional init systems. Services that would normally be managed by systemd or OpenRC often fail to start properly. Need alternative approaches for service management.
  - Implementation Notes:
    - Create startup scripts that run via wsl.conf [boot] command
    - Use background processes with proper pid management
    - Implement service-like functionality without init system dependency
    - Document alternatives for common service needs (Docker, SSH, etc.)
    - Provide examples of converting systemd/OpenRC services to startup scripts
    - Handle service dependencies through script ordering
    - Create simple start/stop/status scripts for manual control
    - Consider using supervisord or similar for process management