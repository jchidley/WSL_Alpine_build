#!/usr/bin/env bash
# Debug script to check home directory detection

source ./common-functions.sh

echo "Debug: Home directory detection"
echo "==============================="
echo "Running as user: $(whoami)"
echo "USER: $USER"
echo "SUDO_USER: $SUDO_USER"
echo "HOME: $HOME"
echo "REAL_HOME from get_real_home(): $(get_real_home)"
echo ""
echo "To fix, run the build script with:"
echo "sudo SUDO_USER=$USER ./wsl-alpine-build.sh"