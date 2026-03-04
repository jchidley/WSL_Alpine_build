# Allowed Tools List

This document lists all the external tools and commands that are used or required by the WSL Alpine Build scripts.

## Required Host Tools

These tools must be installed on the host WSL distribution (e.g., Debian) before running the build scripts:

### Core Requirements
- **bash** - Shell interpreter (all scripts use #!/usr/bin/env bash)
- **sudo** - Privilege escalation for system operations
- **wget** - Download alpine-chroot-install script
- **sha1sum** - Verify downloaded files
- **tar** - Create distribution archive
- **gzip** - Compress distribution archive
- **sed** - Text processing and path manipulation
- **grep** - Pattern matching and text search
- **wsl.exe** - Windows WSL command (accessed via PATH)

### Git Operations
- **git** - Version control operations
- **gh** - GitHub CLI for issue management

## Tools Installed in Alpine

These tools are installed inside the Alpine distribution during build:

### Editors
- **helix** (hx) - Primary text editor with syntax highlighting
- **vim** - Alternative editor (optional)
- **nano** - Simple editor (optional)

### Terminal Tools
- **fd** - Modern find alternative
- **bat** - cat with syntax highlighting
- **zoxide** - Smarter cd command
- **fzf** - Fuzzy finder

### Container Tools
- **docker** - Container runtime
- **docker-compose** - Multi-container orchestration
- **lazydocker** - Terminal UI for Docker

### Development Tools
- **git** - Version control
- **curl** - Data transfer tool
- **tree-sitter-*** - Syntax highlighting grammars

## Shell Built-ins Used

These are shell built-in commands used throughout the scripts:

- echo, test, if/then/else/fi, for/do/done, while, case/esac
- export, source, set, unset, return, exit
- read, shift, true, false
- cd, pwd

## Text Processing Tools

- **tr** - Character translation
- **cut** - Extract columns
- **sort** - Sort lines
- **uniq** - Remove duplicates
- **awk** - Text processing (if needed)
- **head/tail** - Display file portions

## File Operations

- **mkdir** - Create directories
- **rm** - Remove files/directories
- **cp** - Copy files
- **mv** - Move/rename files
- **chmod** - Change permissions
- **chown** - Change ownership
- **find** - Find files
- **ls** - List files

## System Tools

- **mount/umount** - Mount filesystems (used by alpine-chroot-install)
- **chroot** - Change root directory
- **sleep** - Delay execution
- **date** - Display date/time
- **tee** - Write to file and stdout

## Alpine-Specific Tools

- **apk** - Alpine package manager
- **rc-update** - OpenRC service management
- **service** - Service control
- **adduser** - User creation

## Optional Tools

These tools may be referenced but are not required:

- **cmd.exe** - Windows command processor (legacy check)
- **shellcheck** - Bash script linter (development)
- **make** - Build automation (future)

## Notes

1. All scripts use POSIX-compatible features where possible
2. Windows paths are handled via PATH manipulation, not hardcoded
3. The `common-functions.sh` file provides shared functionality
4. Scripts gracefully handle missing optional tools