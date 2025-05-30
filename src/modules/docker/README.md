# Docker Module

The Docker module provides a complete Docker container runtime environment for Alpine WSL.

## What it includes

- Docker Engine (dockerd)
- Docker CLI with compose and buildx plugins
- Containerd and runc
- Lazydocker - Terminal UI for Docker
- WSL-optimized Docker configuration

## Features

### Automatic Configuration
- Docker daemon configured for WSL environment
- Overlay2 storage driver with optimized settings
- BuildKit enabled by default
- Proper cgroup v2 mounting

### User Experience
- `wsluser` automatically added to docker group
- Convenience commands:
  - `docker-start` - Start Docker daemon
  - `docker-stop` - Stop Docker daemon
  - `docker-clean` - Clean up unused resources
  - `docker-nuke` - Remove ALL Docker data (use with caution!)

### Aliases
- `d` - docker
- `dc` - docker compose
- `dps` - docker ps
- `dpsa` - docker ps -a
- `di` - docker images
- `lzd` - lazydocker

## Usage

After installation, start Docker with:
```bash
docker-start
```

Or manually:
```bash
sudo /etc/init.d/docker-wsl start
```

## Notes

- Docker daemon does not start automatically on WSL boot
- Use `docker-start` or add to your `.bashrc` for automatic startup
- First run will pull hello-world image to verify installation