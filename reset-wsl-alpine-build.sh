#!/usr/bin/env bash
set -a # automatically export all variables
source .env
set +a
wsl.exe --unregister $WSL_DISTRIBUTION_NAME
rm ./alpine-chroot-install
rm ~/alpine.wsl.gz
$CHROOT_DIR/destroy -r

