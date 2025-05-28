# Advanced WSL Configuration and Features

This document covers advanced WSL configuration options and features relevant to the Alpine Linux build scripts, based on comprehensive systems documentation.

> **Note**: This documentation is derived from and expands upon concepts detailed in the [Systems-on-Systems](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/) and [File Systems](https://jchidley.github.io/mkdocs-material-test/Linux/2020-01-28-FileSystems/) articles. Please refer to those articles for additional context and examples.

## WSL Configuration Files

### wsl.conf (Per-Distribution Configuration)

The `wsl.conf` file is located at `/etc/wsl.conf` within each WSL distribution and controls distribution-specific settings.

```ini
[boot]
systemd = false                    # Alpine uses OpenRC, not systemd
command = "service docker start"   # Commands to run at boot

[automount]
enabled = true                     # Auto-mount Windows drives
options = "metadata,umask=22,fmask=11"  # Mount options
mountFsTab = true                  # Process /etc/fstab

[network]
generateHosts = true               # Generate /etc/hosts
generateResolvConf = true          # Generate /etc/resolv.conf

[interop]
enabled = true                     # Enable Windows interop
appendWindowsPath = true           # Add Windows PATH to Linux PATH

[user]
default = root                     # Default user (consider changing)
```

### .wslconfig (Global WSL Settings)

The `.wslconfig` file is located at `C:\Users\<username>\.wslconfig` and affects all WSL distributions.

```ini
[wsl2]
memory=4GB                         # Limit memory usage
processors=2                       # Number of processors
swap=8GB                          # Swap file size
swapFile=C:\\temp\\wsl-swap.vhdx # Custom swap location
kernel=C:\\mykernel              # Custom kernel (if needed)
kernelCommandLine=vsyscall=emulate # Kernel command line options
```

## USB Device Support in WSL

To use USB devices in WSL, you need the `usbipd-win` tool on Windows and proper configuration in Linux. For complete details, see the [USB on WSL section](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/#usb-on-wsl).

### Windows Side Setup

```powershell
# Install usbipd
winget install usbipd

# List USB devices
usbipd list

# Share a device (survives reboot)
usbipd bind --busid 4-4

# Attach to WSL (with auto-reattach)
usbipd attach --wsl --auto-attach --busid 4-4
```

### Linux Side Setup

For Alpine Linux in WSL, you need to:

1. Enable udev service in `/etc/wsl.conf`:
```ini
[boot]
command="service udev start"
```

2. Install USB utilities:
```bash
apk add usbutils
```

3. Add udev rules for your devices (e.g., for embedded development):
```bash
# Download and install udev rules
wget https://probe.rs/files/69-probe-rs.rules -O /etc/udev/rules.d/69-probe-rs.rules
udevadm control --reload
udevadm trigger
```

## OpenRC Service Management

Alpine Linux uses OpenRC for service management. For more information about OpenRC on Alpine, see the [OpenRC section](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/#custom-linux-for-wsl-alpine). Here's how to create and manage services:

### Creating a Custom Service

1. Create a service script in `/etc/init.d/`:
```bash
#!/sbin/openrc-run
name="My Service"
description="Description of my service"
command="/usr/local/bin/my-command"
command_args="--option value"
command_background=true            # Run as daemon
pidfile="/run/${RC_SVCNAME}.pid"  # PID file location

depend() {
    need net                       # Network dependency
    after docker                   # Start after Docker
}

start_pre() {
    # Commands to run before starting
    checkpath --directory /var/log/myservice
}
```

2. Make it executable and add to default runlevel:
```bash
chmod +x /etc/init.d/myservice
rc-update add myservice default
rc-service myservice start
```

### Common OpenRC Commands

```bash
# Service management
rc-service <service> start|stop|restart|status
rc-status                          # Show all services status

# Runlevel management
rc-update add <service> <runlevel> # Add to runlevel
rc-update del <service> <runlevel> # Remove from runlevel
rc-update show                     # Show all runlevels

# Shutdown/reboot (within WSL)
openrc shutdown                    # Graceful shutdown
```

## Docker Configuration

### Standard Docker Setup

```bash
# Install Docker
apk add docker docker-cli docker-compose

# Add to boot runlevel
rc-update add docker boot

# Start Docker
rc-service docker start
```

### Rootless Docker Setup

For enhanced security, you can run Docker without root privileges:

```bash
# Install rootless dependencies
apk add docker-rootless-extras

# As a regular user, setup rootless Docker
dockerd-rootless-setuptool.sh install

# Add to shell profile
echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.profile
```

## File Systems and Storage

### Overlay Filesystem

Overlay FS can be useful for creating read-only root filesystems with a writable overlay. See the [Overlay FS documentation](https://jchidley.github.io/mkdocs-material-test/Linux/2020-01-28-FileSystems/#raspberry-pi-overlay-fs) for more details:

```bash
# Install overlay tools
apk add overlayfs-tools

# Create overlay mount
mkdir -p /overlay/lower /overlay/upper /overlay/work /overlay/merged
mount -t overlay overlay \
  -o lowerdir=/overlay/lower,upperdir=/overlay/upper,workdir=/overlay/work \
  /overlay/merged
```

### Windows File System Access

WSL automatically mounts Windows drives under `/mnt/`. To customize this behavior:

```ini
# In /etc/wsl.conf
[automount]
root = /mnt/              # Change mount point
options = "metadata,uid=1000,gid=1000,umask=22,fmask=11"
```

### NTFS-3G for Better Windows Compatibility

```bash
# Install NTFS-3G
apk add ntfs-3g

# Mount with full NTFS support
mount -t ntfs-3g /dev/sdc1 /mnt/windows
```

## WSL-Specific Commands and Integration

### Path Conversion

Convert between Windows and WSL paths:

```bash
# WSL to Windows
wslpath -w /home/user/file.txt
# Output: \\wsl$\Alpine\home\user\file.txt

# Windows to WSL
wslpath -u 'C:\Users\Name\file.txt'
# Output: /mnt/c/Users/Name/file.txt
```

### Accessing WSL from Windows

```powershell
# Access WSL files from Windows
dir \\wsl$\Alpine\home

# Run Linux commands from PowerShell
wsl -d Alpine -- ls -la
```

### Here Documents in WSL Context

When passing scripts from PowerShell to WSL (see the [heredoc section](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/#here-stings-environment-heredoc) for more examples):

```powershell
# PowerShell - No variable expansion
@'
echo $SHELL
uname -a
'@ | wsl -d Alpine --

# PowerShell - With variable expansion
@"
echo Running on $env:COMPUTERNAME
echo Shell is `$SHELL
"@ | wsl -d Alpine --
```

## Performance Optimization

### Memory and CPU Limits

Configure in `.wslconfig`:

```ini
[wsl2]
memory=4GB          # Limit memory
processors=2        # Limit CPU cores
swap=0             # Disable swap if not needed
```

### File System Performance

1. Keep Linux files in the Linux filesystem (not /mnt/c)
2. Use native Linux filesystem for better performance
3. Avoid excessive cross-filesystem operations

## Debugging and Troubleshooting

### Enable Debug Output

```ini
# In .wslconfig
[wsl2]
debugConsole=true   # Show kernel output
```

### Common Issues and Solutions

1. **Service won't start**: Check OpenRC logs
   ```bash
   tail -f /var/log/rc.log
   ```

2. **USB device not found**: Verify udev is running
   ```bash
   rc-service udev status
   ```

3. **Network issues**: Check WSL network configuration
   ```bash
   cat /etc/resolv.conf
   ip addr show
   ```

## Security Considerations

1. **Default User**: Change from root to a regular user
2. **File Permissions**: Be careful with Windows filesystem permissions
3. **Network Security**: WSL shares network with Windows
4. **Docker Security**: Consider rootless mode for production use

## Integration with Development Tools

### Visual Studio Code

```bash
# Install VS Code server
code .  # This will install VS Code server automatically
```

### SSH Server

```bash
# Install and configure SSH
apk add openssh
rc-update add sshd
rc-service sshd start
```

## References

### Published Documentation
These concepts are explored in more detail in the following published articles:
- [Systems-on-Systems](https://jchidley.github.io/mkdocs-material-test/Other/2023-09-24-Systems-on-Systems/) - Comprehensive guide to running systems within systems, including WSL, Docker, and virtual machines
- [File Systems](https://jchidley.github.io/mkdocs-material-test/Linux/2020-01-28-FileSystems/) - Overview of various file systems including OverlayFS and NTFS-3G

### External Documentation
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [Alpine Linux Wiki](https://wiki.alpinelinux.org/)
- [OpenRC Documentation](https://github.com/OpenRC/openrc)
- [Docker on Alpine](https://wiki.alpinelinux.org/wiki/Docker)