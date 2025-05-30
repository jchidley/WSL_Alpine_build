#!/bin/bash
# Docker diagnostics script for Alpine WSL

echo "Docker Diagnostics for Alpine WSL"
echo "================================="
echo ""

# Check if we're in WSL
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo "✓ Running in WSL"
else
    echo "✗ Not running in WSL"
fi

# Check Alpine version
if [ -f /etc/alpine-release ]; then
    echo "✓ Alpine version: $(cat /etc/alpine-release)"
else
    echo "✗ Not running Alpine Linux"
fi

echo ""
echo "Docker Installation Check:"
echo "-------------------------"

# Check if Docker is installed
if command -v docker &>/dev/null; then
    echo "✓ Docker command found: $(which docker)"
    echo "  Version: $(docker --version 2>&1 || echo "Cannot get version")"
else
    echo "✗ Docker command not found"
fi

# Check if dockerd is installed
if command -v dockerd &>/dev/null; then
    echo "✓ Docker daemon found: $(which dockerd)"
else
    echo "✗ Docker daemon (dockerd) not found"
fi

echo ""
echo "Docker Service Status:"
echo "---------------------"

# Check OpenRC service status
if command -v rc-service &>/dev/null; then
    echo "OpenRC service status:"
    rc-service docker status 2>&1 || echo "  Cannot get service status"
else
    echo "✗ OpenRC not available"
fi

# Check if Docker is in runlevel
echo ""
echo "Boot runlevel configuration:"
rc-update show | grep docker || echo "  Docker not in any runlevel"

echo ""
echo "Process Check:"
echo "--------------"

# Check for dockerd process
if pgrep dockerd > /dev/null; then
    echo "✓ dockerd process is running:"
    ps aux | grep '[d]ockerd'
else
    echo "✗ dockerd process is NOT running"
fi

echo ""
echo "Socket Check:"
echo "-------------"

# Check Docker socket
DOCKER_SOCK="/var/run/docker.sock"
if [ -S "$DOCKER_SOCK" ]; then
    echo "✓ Docker socket exists: $DOCKER_SOCK"
    ls -la "$DOCKER_SOCK"
else
    echo "✗ Docker socket does NOT exist: $DOCKER_SOCK"
fi

# Check /var/run directory
echo ""
echo "/var/run directory:"
ls -la /var/run/ | grep -E "(docker|containerd)" || echo "  No Docker-related files found"

echo ""
echo "System Requirements:"
echo "-------------------"

# Check kernel modules
echo "Checking for required kernel modules:"
for module in overlay br_netfilter; do
    if lsmod | grep -q "^$module"; then
        echo "  ✓ $module loaded"
    else
        echo "  ✗ $module NOT loaded"
        echo "    Try: modprobe $module"
    fi
done

# Check cgroups
echo ""
echo "Cgroup configuration:"
if [ -d /sys/fs/cgroup ]; then
    echo "✓ Cgroups mounted at /sys/fs/cgroup"
    # Check for cgroup v2
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        echo "  Using cgroup v2"
    else
        echo "  Using cgroup v1"
    fi
else
    echo "✗ Cgroups not mounted"
fi

echo ""
echo "Log Files:"
echo "----------"

# Check for Docker logs
if [ -f /var/log/docker.log ]; then
    echo "Docker log (last 20 lines):"
    tail -20 /var/log/docker.log
else
    echo "No Docker log file found at /var/log/docker.log"
fi

# Check system logs
echo ""
echo "Recent system messages about Docker:"
dmesg | grep -i docker | tail -10 || echo "  No Docker messages in dmesg"

echo ""
echo "Manual Start Attempt:"
echo "--------------------"
echo "Trying to start Docker manually to see errors..."

# Try to start dockerd manually with debug output
if command -v dockerd &>/dev/null; then
    echo "Running: dockerd --debug --log-level=debug"
    echo "(Press Ctrl+C after seeing the error)"
    timeout 10 dockerd --debug --log-level=debug 2>&1 | head -50
else
    echo "Cannot start dockerd - not found"
fi

echo ""
echo "Recommendations:"
echo "----------------"

# Provide recommendations based on findings
if ! command -v dockerd &>/dev/null; then
    echo "1. Install Docker: apk add docker"
fi

if ! rc-update show | grep -q docker; then
    echo "2. Add Docker to boot: rc-update add docker boot"
fi

if ! pgrep dockerd > /dev/null; then
    echo "3. Try starting Docker manually: rc-service docker start"
    echo "4. Check Docker logs for errors"
fi

echo ""
echo "For WSL-specific Docker issues:"
echo "- Ensure WSL2 is being used (not WSL1)"
echo "- Check if Docker Desktop is interfering"
echo "- Try: sudo dockerd --iptables=false"
echo "- Consider using Docker rootless mode"