# Podman Module

Installs Podman inside the generated Alpine WSL distribution.

## Includes
- podman / podman-remote
- rootless prerequisites (uidmap, subids)
- fuse-overlayfs, slirp4netns, conmon, crun

## Notes
- Designed for **in-distro Podman** (no Podman machine required).
- Adds `/etc/subuid` and `/etc/subgid` entries for `wsluser`.
- Sets `cgroup_manager = "cgroupfs"` for WSL-friendly defaults.
