#!/usr/bin/env bash
# pi-agent module installation script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"

if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing pi-agent module..."
mkdir -p "$ROOTFS_DIR/etc/oobe.d"

cat > "$ROOTFS_DIR/etc/oobe.d/45-pi-agent-packages.sh" << 'EOF'
#!/bin/sh
set -e

echo "Installing dependencies for pi agent..."
apk add --no-cache nodejs npm git curl bash

echo "Installing @mariozechner/pi-coding-agent..."
npm install -g @mariozechner/pi-coding-agent

echo "✓ pi agent installed"
EOF
chmod +x "$ROOTFS_DIR/etc/oobe.d/45-pi-agent-packages.sh"

cat > "$ROOTFS_DIR/usr/local/bin/install-pi-agent" << 'EOF'
#!/bin/sh
set -e
npm install -g @mariozechner/pi-coding-agent
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/install-pi-agent"

log_success "pi-agent module installed successfully"
