#!/usr/bin/env bash
# Base module installation script

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"

# Check ROOTFS_DIR is set
if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing base module..."

# Create package installation script for OOBE
log_progress "Creating package installation script..."
mkdir -p "$ROOTFS_DIR/etc/oobe.d"

cat > "$ROOTFS_DIR/etc/oobe.d/00-base-packages.sh" << 'EOF'
#!/bin/sh
# Install base packages on first boot

echo "Installing base system packages..."

# Update package database
if ! apk update; then
    echo "ERROR: Failed to update package database" >&2
    exit 1
fi

# Install base packages
BASE_PACKAGES="alpine-base openrc util-linux shadow sudo"
if ! apk add --no-cache $BASE_PACKAGES; then
    echo "ERROR: Failed to install base packages" >&2
    exit 1
fi

echo "✓ Base packages installed successfully"

# Ensure default user owns its home directory
if id wsluser >/dev/null 2>&1; then
    chown -R wsluser:wsluser /home/wsluser 2>/dev/null || true
fi

# Clean up package cache
echo "Cleaning package cache..."
apk cache clean
rm -rf /var/cache/apk/*

echo "✓ Package cache cleaned"
EOF

chmod +x "$ROOTFS_DIR/etc/oobe.d/00-base-packages.sh"

# Configure system files
log_progress "Configuring system files..."

# Ensure proper /etc/passwd entries
cat > "$ROOTFS_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/ash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
adm:x:3:4:adm:/var/adm:/sbin/nologin
lp:x:4:7:lp:/var/spool/lpd:/sbin/nologin
sync:x:5:0:sync:/sbin:/bin/sync
shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown
halt:x:7:0:halt:/sbin:/sbin/halt
mail:x:8:12:mail:/var/spool/mail:/sbin/nologin
news:x:9:13:news:/usr/lib/news:/sbin/nologin
uucp:x:10:14:uucp:/var/spool/uucppublic:/sbin/nologin
operator:x:11:0:operator:/root:/bin/sh
man:x:13:15:man:/usr/man:/sbin/nologin
postmaster:x:14:12:postmaster:/var/spool/mail:/sbin/nologin
cron:x:16:16:cron:/var/spool/cron:/sbin/nologin
ftp:x:21:21::/var/lib/ftp:/sbin/nologin
sshd:x:22:22:sshd:/dev/null:/sbin/nologin
at:x:25:25:at:/var/spool/cron/atjobs:/sbin/nologin
squid:x:31:31:Squid:/var/cache/squid:/sbin/nologin
xfs:x:33:33:X Font Server:/etc/X11/fs:/sbin/nologin
games:x:35:35:games:/usr/games:/sbin/nologin
postgres:x:70:70::/var/lib/postgresql:/bin/sh
cyrus:x:85:12::/usr/cyrus:/sbin/nologin
vpopmail:x:89:89::/var/vpopmail:/sbin/nologin
ntp:x:123:123:NTP:/var/empty:/sbin/nologin
smmsp:x:209:209:smmsp:/var/spool/mqueue:/sbin/nologin
guest:x:405:100:guest:/dev/null:/sbin/nologin
nobody:x:65534:65534:nobody:/:/sbin/nologin
EOF

# Create group file
cat > "$ROOTFS_DIR/etc/group" << 'EOF'
root:x:0:root
bin:x:1:root,bin,daemon
daemon:x:2:root,bin,daemon
sys:x:3:root,bin,adm
adm:x:4:root,adm,daemon
tty:x:5:
disk:x:6:root,adm
lp:x:7:lp
mem:x:8:
kmem:x:9:
wheel:x:10:root
floppy:x:11:root
mail:x:12:mail
news:x:13:news
uucp:x:14:uucp
man:x:15:man
cron:x:16:cron
console:x:17:
audio:x:18:
cdrom:x:19:
dialout:x:20:root
ftp:x:21:
sshd:x:22:
input:x:23:
at:x:25:at
tape:x:26:root
video:x:27:root
netdev:x:28:
readproc:x:30:
squid:x:31:squid
xfs:x:33:xfs
kvm:x:34:
games:x:35:
shadow:x:42:
cdrw:x:80:
www-data:x:82:
usb:x:85:
vpopmail:x:89:
users:x:100:games
ntp:x:123:
nofiles:x:200:
smmsp:x:209:
locate:x:245:
abuild:x:300:
utmp:x:406:
ping:x:999:
nogroup:x:65533:
nobody:x:65534:
EOF

# Create default user (UID 1000 as per Microsoft recommendations)
log_progress "Creating default WSL user..."
cat >> "$ROOTFS_DIR/etc/passwd" << 'EOF'
wsluser:x:1000:1000:WSL User:/home/wsluser:/bin/ash
EOF

cat >> "$ROOTFS_DIR/etc/group" << 'EOF'
wsluser:x:1000:
EOF

# Create shadow file (passwords will be set by OOBE)
touch "$ROOTFS_DIR/etc/shadow"
chmod 640 "$ROOTFS_DIR/etc/shadow"

# Create user home directory
mkdir -p "$ROOTFS_DIR/home/wsluser"

# Configure sudo
log_progress "Configuring sudo..."
mkdir -p "$ROOTFS_DIR/etc/sudoers.d"
cat > "$ROOTFS_DIR/etc/sudoers.d/wsluser" << 'EOF'
# Allow wsluser to use sudo without password
wsluser ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 "$ROOTFS_DIR/etc/sudoers.d/wsluser"

# Create basic shell configuration
log_progress "Creating shell configuration..."
# Alpine uses .profile for ash shell configuration
cat > "$ROOTFS_DIR/home/wsluser/.ashrc" << 'EOF'
# Alpine WSL .ashrc

# User specific aliases and functions
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Set a nice prompt
PS1='\033[01;32m\u@\h\033[00m:\033[01;34m\w\033[00m\$ '

# Set default editor
export EDITOR=vi
export VISUAL=vi

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# Copy to root user as well
cp "$ROOTFS_DIR/home/wsluser/.ashrc" "$ROOTFS_DIR/root/.ashrc"

# Create .profile
cat > "$ROOTFS_DIR/home/wsluser/.profile" << 'EOF'
# Alpine WSL .profile

# Source .ashrc if it exists
if [ -f "$HOME/.ashrc" ]; then
    . "$HOME/.ashrc"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF

# Copy to root user
cp "$ROOTFS_DIR/home/wsluser/.profile" "$ROOTFS_DIR/root/.profile"

# Fix permissions
chmod 755 "$ROOTFS_DIR/home/wsluser"
chmod 644 "$ROOTFS_DIR/home/wsluser/.ashrc"
chmod 644 "$ROOTFS_DIR/home/wsluser/.profile"
# Ensure default user owns home directory (required for rootless podman)
chown -R 1000:1000 "$ROOTFS_DIR/home/wsluser"

# Configure services
log_progress "Configuring OpenRC for WSL..."

# Create OpenRC configuration for WSL
mkdir -p "$ROOTFS_DIR/etc/conf.d"
cat > "$ROOTFS_DIR/etc/conf.d/wsl" << 'EOF'
# WSL-specific OpenRC configuration
rc_sys="lxc"
rc_controller_cgroups="NO"
rc_depend_strict="NO"
rc_need="!net !dev !udev-mount !sysfs !checkfs !fsck !netmount !urandom !swap"
EOF

# Disable services that don't work in WSL
for service in hwclock hwdrivers modules modules-load modloop; do
    if [[ -e "$ROOTFS_DIR/etc/init.d/$service" ]]; then
        rm -f "$ROOTFS_DIR/etc/runlevels"/*/"$service" 2>/dev/null || true
    fi
done

# Create machine-id for systemd compatibility
touch "$ROOTFS_DIR/etc/machine-id"

# Clean up
log_progress "Cleaning up..."
# Package cache cleaning will happen during OOBE after packages are installed

log_success "Base module installed successfully"