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

echo "Installing pi-agent prerequisites and CLI..."
if ! /usr/local/bin/install-pi-agent; then
    echo "ERROR: Failed to install pi-agent" >&2
    exit 1
fi

echo "✓ pi agent installed"
EOF
chmod +x "$ROOTFS_DIR/etc/oobe.d/45-pi-agent-packages.sh"

cat > "$ROOTFS_DIR/usr/local/bin/install-pi-agent" << 'EOF'
#!/bin/sh
set -e

PKG="@mariozechner/pi-coding-agent"
PI_CACHE_DIR="${PI_CACHE_DIR:-/var/cache/pi-agent}"
PI_STATE_DIR="${PI_STATE_DIR:-/var/lib/pi-agent}"

install_pkgs_as_root() {
    apk add --no-cache nodejs-current npm git bash ca-certificates direnv ripgrep fd
}

is_local_command() {
    cmd_path="$(command -v "$1" 2>/dev/null || true)"
    [ -n "$cmd_path" ] || return 1
    case "$cmd_path" in
        /mnt/*) return 1 ;;
    esac
    return 0
}

ensure_system_deps() {
    missing=""
    for cmd in node npm git bash direnv rg fd; do
        is_local_command "$cmd" || missing="$missing $cmd"
    done

    [ -z "$missing" ] && return 0

    if [ "$(id -u)" -eq 0 ]; then
        install_pkgs_as_root
    elif command -v sudo >/dev/null 2>&1; then
        sudo apk add --no-cache nodejs-current npm git bash ca-certificates direnv ripgrep fd
    else
        echo "ERROR: missing prerequisites:$missing"
        echo "Run as root once: wsl.exe -d \$WSL_DISTRO_NAME -u root -- install-pi-agent"
        exit 1
    fi
}

setup_cache_dirs() {
    if [ "$(id -u)" -eq 0 ]; then
        mkdir -p "$PI_CACHE_DIR" "$PI_STATE_DIR" /var/cache/npm
        export npm_config_cache="/var/cache/npm"
    else
        mkdir -p "$HOME/.cache/pi-agent" "$HOME/.local/state/pi-agent" "$HOME/.npm"
        PI_CACHE_DIR="$HOME/.cache/pi-agent"
        PI_STATE_DIR="$HOME/.local/state/pi-agent"
        export npm_config_cache="$HOME/.npm"
    fi
}

get_latest_version() {
    npm view "$PKG" version 2>/dev/null | tr -d '\r\n'
}

get_installed_version() {
    npm list -g --depth=0 "$PKG" 2>/dev/null | sed -n 's/.*@mariozechner\/pi-coding-agent@\([0-9][^ ]*\).*/\1/p' | head -n1
}

cache_tarball_for_version() {
    version="$1"
    mkdir -p "$PI_CACHE_DIR"

    tarball="$PI_CACHE_DIR/pi-coding-agent-${version}.tgz"
    if [ -f "$tarball" ]; then
        echo "$tarball"
        return 0
    fi

    packed_name=$(npm pack "$PKG@$version" --pack-destination "$PI_CACHE_DIR" 2>/dev/null | tail -n1)
    if [ -z "$packed_name" ] || [ ! -f "$PI_CACHE_DIR/$packed_name" ]; then
        return 1
    fi

    mv "$PI_CACHE_DIR/$packed_name" "$tarball"
    echo "$tarball"
}

install_cli() {
    latest="$(get_latest_version || true)"
    installed="$(get_installed_version || true)"

    if [ -n "$latest" ] && [ "$installed" = "$latest" ] && is_local_command pi; then
        echo "✓ pi already up to date ($installed)"
        printf '%s\n' "$latest" > "$PI_STATE_DIR/latest"
        return 0
    fi

    if [ -n "$latest" ]; then
        echo "Installing $PKG@$latest..."
        tarball="$(cache_tarball_for_version "$latest" || true)"

        if [ -n "$tarball" ] && [ -f "$tarball" ]; then
            npm install -g "$tarball"
        else
            npm install -g "$PKG@latest"
        fi

        post="$(get_installed_version || true)"
        if [ "$post" = "$latest" ]; then
            printf '%s\n' "$latest" > "$PI_STATE_DIR/latest"
        else
            echo "WARNING: installed version ($post) did not match latest ($latest), continuing"
        fi

        return 0
    fi

    echo "WARNING: unable to resolve latest version, installing unpinned package"
    npm install -g "$PKG"
}

ensure_system_deps
setup_cache_dirs
install_cli

if is_local_command pi; then
    echo "✓ pi command available"
elif is_local_command pi-coding-agent; then
    echo "✓ pi-coding-agent command available"
else
    echo "⚠ Installed but no local pi command found in PATH"
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

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash 2>/dev/null || fnm env --shell sh 2>/dev/null)"
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
