# Base Module

The base module provides the essential Alpine Linux system configuration for WSL.

## What it includes

- Core Alpine packages (alpine-base, openrc, util-linux)
- System utilities (sudo, bash, coreutils, procps)
- Default WSL user configuration (wsluser with sudo access)
- OpenRC configuration optimized for WSL
- Basic shell configuration (.bashrc, .profile)

## System Configuration

### Users
- Creates default user `wsluser` with UID 1000
- Configures passwordless sudo for wsluser
- Sets up proper home directory structure

### Shell
- Configures bash as default shell
- Provides color-enabled ls aliases
- Sets up PATH for local binaries

### Services
- Configures OpenRC for WSL environment
- Disables incompatible services (hwclock, modules, etc.)
- Sets rc_sys="lxc" for container compatibility

## Requirements

This module has no dependencies and should always be installed first.