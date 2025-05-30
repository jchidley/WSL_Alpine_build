#!/bin/ash
# Fix Docker configuration in Alpine WSL

echo "Docker Fix Script for Alpine WSL"
echo "================================"
echo ""

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Installing..."
    apk update
    apk add docker
fi

# Remove any existing symbolic links (from incorrect setup)
echo "Cleaning up old configuration..."
rm -f /etc/runlevels/boot/docker 2>/dev/null
rm -f /etc/runlevels/default/docker 2>/dev/null

# Properly add Docker to boot runlevel using rc-update
echo "Adding Docker to boot runlevel..."
rc-update add docker boot

# Create docker group if it doesn't exist
if ! grep -q "^docker:" /etc/group; then
    echo "Creating docker group..."
    addgroup docker
fi

# Add current user to docker group if not root
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    echo "Adding $SUDO_USER to docker group..."
    addgroup "$SUDO_USER" docker
fi

# Ensure cgroups are properly configured for WSL
echo "Checking cgroup configuration..."
if ! grep -q "cgroup" /etc/fstab; then
    echo "Adding cgroup mounts to /etc/fstab..."
    cat >> /etc/fstab << 'EOF'

# Cgroups for Docker
cgroup2 /sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate 0 0
EOF
fi

# Start OpenRC if not running
if ! rc-status &>/dev/null; then
    echo "Starting OpenRC..."
    openrc boot
fi

# Try to start Docker
echo ""
echo "Starting Docker service..."
rc-service docker start

# Wait for Docker to be ready
echo "Waiting for Docker daemon..."
for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        echo "✓ Docker is ready!"
        break
    fi
    printf "."
    sleep 1
done
echo ""

# Verify Docker is working
if docker info >/dev/null 2>&1; then
    echo ""
    echo "✓ Docker is working correctly!"
    echo ""
    docker version
    echo ""
    echo "You can now use Docker. Try: docker run hello-world"
else
    echo ""
    echo "✗ Docker is still not working. Checking logs..."
    echo ""
    
    # Show recent Docker logs
    if [ -f /var/log/docker.log ]; then
        echo "Recent Docker logs:"
        tail -20 /var/log/docker.log
    fi
    
    # Try manual start to see errors
    echo ""
    echo "Attempting manual start to diagnose..."
    dockerd --debug 2>&1 | head -20
    
    echo ""
    echo "Common fixes to try:"
    echo "1. Ensure you're using WSL2 (not WSL1): wsl.exe --list --verbose"
    echo "2. Update WSL: wsl.exe --update"
    echo "3. Try running Docker without iptables: dockerd --iptables=false"
    echo "4. Check if Docker Desktop is interfering"
fi