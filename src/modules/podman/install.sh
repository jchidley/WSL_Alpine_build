#!/usr/bin/env bash
# Podman module installation script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"

if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing podman module..."
mkdir -p "$ROOTFS_DIR/etc/oobe.d"

cat > "$ROOTFS_DIR/etc/oobe.d/35-podman-packages.sh" << 'EOF'
#!/bin/sh
set -e

echo "Installing Podman packages..."
apk add --no-cache \
  podman podman-remote fuse-overlayfs slirp4netns \
  conmon crun uidmap shadow-subids iptables ip6tables

echo "Configuring rootless podman defaults..."
if ! grep -q '^wsluser:' /etc/subuid 2>/dev/null; then
  echo 'wsluser:100000:65536' >> /etc/subuid
fi
if ! grep -q '^wsluser:' /etc/subgid 2>/dev/null; then
  echo 'wsluser:100000:65536' >> /etc/subgid
fi

mkdir -p /home/wsluser/.config/containers
cat > /home/wsluser/.config/containers/containers.conf << 'EOC'
[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"
EOC
chown -R 1000:1000 /home/wsluser/.config

echo "Podman installed. Use: podman info"
EOF

chmod +x "$ROOTFS_DIR/etc/oobe.d/35-podman-packages.sh"
log_success "Podman module installed successfully"
