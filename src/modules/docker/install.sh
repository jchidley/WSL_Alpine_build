#!/usr/bin/env bash
# Docker module installation script

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"
# shellcheck source=src/lib/package.sh
source "${PROJECT_ROOT}/src/lib/package.sh"

# Check ROOTFS_DIR is set
if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing docker module..."

# Install Docker packages
log_progress "Installing Docker and related packages..."
if ! install_packages "$ROOTFS_DIR" \
    docker \
    docker-cli \
    docker-cli-compose \
    docker-cli-buildx \
    containerd \
    runc \
    ca-certificates \
    iptables \
    ip6tables \
    git; then
    log_error "Failed to install Docker packages"
    exit 1
fi

# Install lazydocker from testing repository
log_progress "Installing lazydocker..."
if ! run_apk_in_rootfs "$ROOTFS_DIR" add --no-cache lazydocker@testing; then
    log_warning "Failed to install lazydocker from testing repository"
fi

# Configure Docker daemon
log_progress "Configuring Docker daemon..."
mkdir -p "$ROOTFS_DIR/etc/docker"
cat > "$ROOTFS_DIR/etc/docker/daemon.json" << 'EOF'
{
    "hosts": ["unix:///var/run/docker.sock"],
    "log-level": "warn",
    "storage-driver": "overlay2",
    "iptables": true,
    "ipv6": false,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "features": {
        "buildkit": true
    }
}
EOF

# Create Docker service configuration
log_progress "Configuring Docker service..."
mkdir -p "$ROOTFS_DIR/etc/conf.d"
cat > "$ROOTFS_DIR/etc/conf.d/docker" << 'EOF'
# Docker service configuration for WSL
DOCKER_OPTS=""
EOF

# Create Docker init script wrapper for WSL
cat > "$ROOTFS_DIR/etc/init.d/docker-wsl" << 'EOF'
#!/sbin/openrc-run

name="Docker (WSL)"
description="Docker container runtime for WSL"

depend() {
    need localmount
}

start() {
    ebegin "Starting Docker daemon"
    
    # Ensure cgroup v2 is mounted
    if ! mountpoint -q /sys/fs/cgroup; then
        mount -t cgroup2 none /sys/fs/cgroup 2>/dev/null || true
    fi
    
    # Start dockerd in background
    start-stop-daemon --start --background \
        --exec /usr/bin/dockerd \
        --pidfile /var/run/docker.pid \
        --make-pidfile
    
    # Wait for Docker to be ready
    local tries=0
    while [ $tries -lt 30 ]; do
        if docker version >/dev/null 2>&1; then
            eend 0
            return 0
        fi
        sleep 1
        tries=$((tries + 1))
    done
    
    eend 1 "Docker failed to start"
    return 1
}

stop() {
    ebegin "Stopping Docker daemon"
    start-stop-daemon --stop --pidfile /var/run/docker.pid
    eend $?
}

status() {
    if docker version >/dev/null 2>&1; then
        einfo "Docker is running"
        return 0
    else
        eerror "Docker is not running"
        return 1
    fi
}
EOF
chmod +x "$ROOTFS_DIR/etc/init.d/docker-wsl"

# Add docker group
if ! grep -q "^docker:" "$ROOTFS_DIR/etc/group"; then
    echo "docker:x:999:" >> "$ROOTFS_DIR/etc/group"
fi

# Add wsluser to docker group
sed -i 's/^docker:x:999:$/docker:x:999:wsluser/' "$ROOTFS_DIR/etc/group"

# Create Docker directories
mkdir -p "$ROOTFS_DIR/var/lib/docker"
mkdir -p "$ROOTFS_DIR/etc/docker/cli-plugins"

# Create convenience scripts
log_progress "Creating Docker convenience scripts..."
cat > "$ROOTFS_DIR/usr/local/bin/docker-start" << 'EOF'
#!/bin/bash
# Start Docker daemon in WSL

if docker version >/dev/null 2>&1; then
    echo "Docker is already running"
    exit 0
fi

echo "Starting Docker daemon..."
sudo /etc/init.d/docker-wsl start
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/docker-start"

cat > "$ROOTFS_DIR/usr/local/bin/docker-stop" << 'EOF'
#!/bin/bash
# Stop Docker daemon in WSL

if ! docker version >/dev/null 2>&1; then
    echo "Docker is not running"
    exit 0
fi

echo "Stopping Docker daemon..."
sudo /etc/init.d/docker-wsl stop
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/docker-stop"

# Add Docker aliases to user bashrc
cat >> "$ROOTFS_DIR/home/wsluser/.bashrc" << 'EOF'

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlog='docker logs'
alias dexec='docker exec -it'
alias lzd='lazydocker'

# Docker functions
docker-clean() {
    echo "Cleaning up Docker..."
    docker container prune -f
    docker image prune -f
    docker volume prune -f
    docker network prune -f
}

docker-nuke() {
    echo "WARNING: This will remove ALL Docker data!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker rmi $(docker images -aq) 2>/dev/null || true
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        docker network rm $(docker network ls -q | grep -v bridge | grep -v host | grep -v none) 2>/dev/null || true
        echo "Docker cleanup complete"
    fi
}
EOF

# Create Docker first-run script
cat > "$ROOTFS_DIR/etc/docker-firstrun.sh" << 'EOF'
#!/bin/bash
# Docker first-run configuration

if [ -f /etc/docker-firstrun.done ]; then
    exit 0
fi

echo "Configuring Docker for first run..."

# Ensure Docker directories have correct permissions
sudo chown root:root /var/lib/docker
sudo chmod 710 /var/lib/docker

# Start Docker daemon
sudo /etc/init.d/docker-wsl start

# Verify Docker is working
if docker version >/dev/null 2>&1; then
    echo "✓ Docker is running successfully"
    
    # Pull hello-world image as test
    echo "Testing Docker with hello-world..."
    docker run --rm hello-world
else
    echo "✗ Docker failed to start"
    echo "Please check logs and try manually: sudo dockerd"
fi

touch /etc/docker-firstrun.done
EOF
chmod +x "$ROOTFS_DIR/etc/docker-firstrun.sh"

# Add Docker info to login message
cat > "$ROOTFS_DIR/etc/docker-motd" << 'EOF'

Docker is installed! Commands:
  docker-start    - Start Docker daemon
  docker-stop     - Stop Docker daemon
  docker-clean    - Clean unused Docker resources
  lzd            - Launch lazydocker TUI

EOF

log_success "Docker module installed successfully"