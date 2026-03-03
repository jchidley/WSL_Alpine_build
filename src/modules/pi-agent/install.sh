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

echo "Installing pi-agent prerequisites from Alpine repositories..."
# pi-agent requires Node >= 20; include shell/search tools used by pi workflows
apk add --no-cache nodejs-current npm git bash ca-certificates direnv ripgrep fd

echo "Installing @mariozechner/pi-coding-agent via npm..."
npm install -g @mariozechner/pi-coding-agent

echo "✓ pi agent installed"
EOF
chmod +x "$ROOTFS_DIR/etc/oobe.d/45-pi-agent-packages.sh"

cat > "$ROOTFS_DIR/usr/local/bin/install-pi-agent" << 'EOF'
#!/bin/sh
set -e

install_pkgs_as_root() {
    apk add --no-cache nodejs-current npm git bash ca-certificates direnv ripgrep fd
}

ensure_system_deps() {
    missing=""
    for cmd in node npm git bash direnv rg fd; do
        command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
    done

    [ -z "$missing" ] && return 0

    if [ "$(id -u)" -eq 0 ]; then
        install_pkgs_as_root
    elif command -v sudo >/dev/null 2>&1; then
        sudo apk add --no-cache nodejs-current npm git bash ca-certificates direnv ripgrep fd
    else
        echo "ERROR: missing prerequisites:$missing"
        echo "Run as root once: wsl -d \$WSL_DISTRO_NAME -u root -- install-pi-agent"
        exit 1
    fi
}

install_cli() {
    echo "Installing @mariozechner/pi-coding-agent..."
    if [ "$(id -u)" -eq 0 ]; then
        npm install -g @mariozechner/pi-coding-agent
    elif command -v sudo >/dev/null 2>&1; then
        sudo npm install -g @mariozechner/pi-coding-agent
    else
        npm install -g @mariozechner/pi-coding-agent
    fi
}

ensure_system_deps
install_cli

if command -v pi >/dev/null 2>&1; then
    echo "✓ pi command available"
elif command -v pi-coding-agent >/dev/null 2>&1; then
    echo "✓ pi-coding-agent command available"
else
    echo "⚠ Installed but no pi command found in PATH"
fi
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/install-pi-agent"

cat > "$ROOTFS_DIR/usr/local/bin/debian-ak-export" << 'EOF'
#!/bin/sh
set -e

DEBIAN_KEYS_DISTRO="${DEBIAN_KEYS_DISTRO:-Debian}"
DEBIAN_KEYS_WORKDIR="${DEBIAN_KEYS_WORKDIR:-/home/jack}"
DEBIAN_KEYS_CMD="${DEBIAN_KEYS_CMD:-/home/jack/tools/api-keys/bin/ak export}"

if command -v wsl.exe >/dev/null 2>&1; then
    WSL_EXE="wsl.exe"
elif [ -x /mnt/c/Windows/System32/wsl.exe ]; then
    WSL_EXE="/mnt/c/Windows/System32/wsl.exe"
else
    echo "ERROR: wsl.exe not found" >&2
    exit 1
fi

"$WSL_EXE" -d "$DEBIAN_KEYS_DISTRO" --cd "$DEBIAN_KEYS_WORKDIR" -e bash -lc "$DEBIAN_KEYS_CMD" | tr -d '\r\000'
EOF
chmod +x "$ROOTFS_DIR/usr/local/bin/debian-ak-export"

mkdir -p "$ROOTFS_DIR/etc/profile.d"
cat > "$ROOTFS_DIR/etc/profile.d/pi-agent-env.sh" << 'EOF'
# pi-agent shell helpers (Debian ak bridge + direnv)

load-api-keys() {
    eval "$(debian-ak-export)"
}

# Convenience wrapper so `pi` has keys without manual steps.
# Falls back cleanly if key loading fails.
pi() {
    load-api-keys >/dev/null 2>&1 || true
    command pi "$@"
}

if command -v direnv >/dev/null 2>&1; then
    if [ -n "${BASH_VERSION:-}" ]; then
        eval "$(direnv hook bash)"
    else
        eval "$(direnv hook ash 2>/dev/null || direnv hook sh 2>/dev/null)"
    fi
fi
EOF
chmod +x "$ROOTFS_DIR/etc/profile.d/pi-agent-env.sh"

# Default pi model configuration
mkdir -p "$ROOTFS_DIR/home/wsluser/.pi/agent"
cat > "$ROOTFS_DIR/home/wsluser/.pi/agent/settings.json" << 'EOF'
{
  "defaultProvider": "openai",
  "defaultModel": "gpt-5.3-codex",
  "defaultThinkingLevel": "medium"
}
EOF
chown -R 1000:1000 "$ROOTFS_DIR/home/wsluser/.pi"

mkdir -p "$ROOTFS_DIR/root/.pi/agent"
cat > "$ROOTFS_DIR/root/.pi/agent/settings.json" << 'EOF'
{
  "defaultProvider": "openai",
  "defaultModel": "gpt-5.3-codex",
  "defaultThinkingLevel": "medium"
}
EOF

log_success "pi-agent module installed successfully"