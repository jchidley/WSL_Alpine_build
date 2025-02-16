#!/usr/bin/env bash
# Run it on a host Linux distribution, tested on Debian
#!/bin/ash
set -a # automatically export all variables
source .env
set +a

# https://github.com/alpinelinux/alpine-chroot-install
if ! echo 'ccbf65f85cdc351851f8ad025bb3e65bae4d5b06 alpine-chroot-install' | sha1sum -c; then
    rm alpine-chroot-install
  fi
if [[ ! -f alpine-chroot-install ]]; then 
  wget https://raw.githubusercontent.com/alpinelinux/alpine-chroot-install/v0.14.0/alpine-chroot-install \
  && echo 'ccbf65f85cdc351851f8ad025bb3e65bae4d5b06 alpine-chroot-install' | sha1sum -c \
  || exit 1
fi

# minimal apps to make initial build less painful but still small. oobe.sh takes
# care of the rest
$SUDO ./alpine-chroot-install -d $CHROOT_DIR \
-p helix \
-p tree-sitter-bash \
-p tree-sitter-regex \
-p tree-sitter-json \
-p tree-sitter-toml \
-p tree-sitter-ini \
-p tree-sitter-comment \
-p openrc \
-p fd \
-p bat \
-p zoxide \
-p fzf 
# unbind the various mounts for chroot: we don't want them for wsl
$CHROOT_DIR/destroy

$SUDO mkdir -p $CHROOT_DIR/usr/lib/wsl
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/usr/lib/wsl/terminal-profile.json
{
  "profiles": [
    {
      "colorScheme": "Gruvbox Dark (Hard)"
    }
  ]
}
EOF

cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/wsl-distribution.conf
# /etc/wsl-distribution.conf

[oobe]
command = /etc/oobe.sh
defaultUid = 0 # root user, can use 1000 this needs to match the same id used in oobe.sh
defaultName = $WSL_DISTRIBUTION_NAME

[shortcut]
icon = /usr/lib/wsl/my-icon.ico

[windowsterminal]
ProfileTemplate = /usr/lib/wsl/terminal-profile.json
EOF

cat << EOF | $SUDO tee -a > /dev/null $CHROOT_DIR/etc/apk/repositories
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

# This runs on inital start to update apk and install the other tools, this keeps
# the initial image small but with the basic usability tools.
# Assumed to run as root
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/oobe.sh
#!/bin/ash
# /etc/oobe.sh
apk update && apk upgrade
# apk del tree-sitter-markdown 
apk add tree-sitter-markdown@testing \
docker \
lazydocker \
tree-sitter-css \
tree-sitter-html \
tree-sitter-javascript \
tree-sitter-typescript \
tree-sitter-python \
tree-sitter-rust \
tree-sitter-c
ln -s /etc/init.d/docker /etc/runlevels/boot/docker
mkdir -p ~/.config/helix
cat << HELIX_EOF > ~/.config/helix/config.toml
theme = "gruvbox_dark_hard"
HELIX_EOF
# remove files relevant for chroot install, and extra env.sh
rm /enter-chroot /destroy /env.sh
echo "====================================================="
echo "to complete the installation, exit this shell and run"
echo "wsl.exe -t $WSL_DISTRIBUTION_NAME"
EOF
$SUDO chmod +x $CHROOT_DIR/etc/oobe.sh

# seems to be required for docker
cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/network/interfaces
# /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback
EOF

cat << EOF | $SUDO tee > /dev/null $CHROOT_DIR/etc/wsl.conf
# /etc/wsl.conf

[boot]
systemd=false # if true, wsl will run systemd on boot
command = /sbin/openrc boot
EOF

cat << 'EOF' | $SUDO tee > /dev/null $CHROOT_DIR/root/.profile
export COLORTERM=truecolor
eval "$(zoxide init posix --hook prompt)" # not working
EOF

# wsl.exe --unregister $WSL_DISTRIBUTION_NAME # this needs to be manual
cd $CHROOT_DIR
# if you're really worried about size, use --best for gzip
$SUDO tar --numeric-owner --absolute-names -c  * | gzip --fast > ~/alpine.wsl.gz
wsl.exe --install --from-file ~/alpine.wsl.gz # surprisingly fast with alpine.
