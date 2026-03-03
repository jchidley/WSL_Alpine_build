# How to choose and validate a from-scratch Windows WSL2 setup

Use this guide when setting up this project on a fresh Windows machine and deciding which builder distro to use.

## Prerequisites
- Windows 11/10 with WSL2
- PowerShell access
- Internet access for distro install and package download

## 1) Understand the architecture
This project is not a pure PowerShell build flow.

You need one Linux **builder distro** in WSL to run:
- `git clone`
- `./wsl-alpine ...`
- packaging tools (`tar`, `gzip`, `fakeroot`)

That builder then imports the target Alpine distro via `wsl.exe`.

## 2) Pick a builder distro

### Option A: Debian/Ubuntu builder
```powershell
wsl --install -d Debian
```

Inside builder:
```bash
sudo apt update
sudo apt install -y git wget tar gzip fakeroot
mkdir -p ~/tools
cd ~/tools
git clone https://github.com/jchidley/WSL_Alpine_build.git
cd WSL_Alpine_build
```

### Option B: Arch Linux builder (official)
```powershell
wsl --install -d archlinux
```

Inside builder:
```bash
pacman -Syu --noconfirm
pacman -S --noconfirm git bash wget tar gzip fakeroot
mkdir -p ~/tools
cd ~/tools
git clone https://github.com/jchidley/WSL_Alpine_build.git
cd WSL_Alpine_build
```

### Option C: `wsl --install -d Alpine`
On this machine, Alpine is not in `wsl --list --online`, so use Option A or B as the builder and generate Alpine targets with this repo.

## 3) Build a pi-ready Alpine target
From the chosen builder distro:
```bash
cd ~/tools/WSL_Alpine_build
./wsl-alpine build --name alpine-pi-agent --modules base,pi-agent
```

First boot setup:
```powershell
wsl -d alpine-pi-agent -u root -- /etc/oobe.sh
```

Verify:
```powershell
wsl -d alpine-pi-agent -- sh -lc "pi --version"
```

## 4) Compare Debian vs Arch builder experience (optional)
Run identical builds from each builder and compare wall-clock time.

Script used during testing:
- `C:\Users\jackc\AppData\Local\Temp\compare-wsl-builders.ps1`

Observed timings (same target: `base,pi-agent`):
- Build via Debian-fresh: **7.21 s**
- Build via archlinux: **8.66 s**
- OOBE (Debian-built target): **38.52 s**
- OOBE (Arch-built target): **37.67 s**

Interpretation: both builder distros are effectively equivalent for this workflow.

## 5) Reclaim WSL disk space when VHDX grows
WSL VHDX files grow and may not automatically shrink.

PowerShell (Admin):
```powershell
wsl --shutdown
diskpart
```

In `diskpart`:
```text
select vdisk file="C:\Users\<you>\AppData\Local\Packages\<DistroPackage>\LocalState\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

Verify:
```powershell
(Get-Item "C:\...\ext4.vhdx").Length / 1GB
```

## Results from this machine

### Builder baseline RAM (`free -h` after `wsl --shutdown`)
- Arch: ~563 MiB used
- Debian-fresh: ~540 MiB used

### Builder VHDX footprint (later run)
- Arch: 941 MiB (0.919 GiB)
- Debian-fresh: 1020 MiB (0.996 GiB)

### pi target VHDX footprint
- `alpine-pi-agent`: 624 MiB (0.609 GiB)
- `alpine-pi-agent-deb`: 621 MiB (0.606 GiB)
- `alpine-pi-agent-arch`: 619 MiB (0.604 GiB)

### Compaction result
- Debian VHDX before compaction cycle: ~345.357 GiB
- Debian VHDX after cleanup + `diskpart compact vdisk`: ~214.202 GiB
- Reclaimed: ~131.155 GiB

## Notes
- Keep active Linux work on `~/...` (ext4), not `/mnt/c/...`.
- Use `wsl --shutdown` before repeatable timing or compaction.
- For `pi` credentials, choose one source-of-truth model (builder-side key store vs target-side auth/env).