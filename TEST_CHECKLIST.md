# Alpine WSL Modular Build Test Checklist

## Quick Test

Run the automated test script:
```bash
./test-modular-full.sh
```

## Manual Testing Steps

### 1. Build and Install
```bash
# Build with default name
./wsl-alpine-build-modular.sh

# Or build with custom name
./wsl-alpine-build-modular.sh --name alpine-dev --verbose
```

### 2. Access the Distribution
```bash
# Enter as root (default)
wsl.exe -d alpine-wsl -u root --cd /

# Or if you used a custom name
wsl.exe -d alpine-dev -u root --cd /
```

### 3. Verify Core Packages
```bash
# Check installed packages
apk list --installed | grep -E "(helix|docker|fd|bat|zoxide|fzf|lazydocker)"

# Test each tool
helix --version
fd --version
bat --version
zoxide --version
fzf --version
docker --version
lazydocker --version
```

### 4. Test Helix Editor
```bash
# Open a file to test syntax highlighting
hx /etc/apk/repositories

# Check theme (should show Gruvbox colors)
# Verify config exists
cat ~/.config/helix/config.toml
```

### 5. Test Docker
```bash
# Check service status
rc-status

# Start Docker if not running
service docker start

# Test Docker
docker run hello-world

# Test lazydocker
lazydocker
```

### 6. Test Terminal Tools
```bash
# Test fd (find alternative)
fd -H .profile ~

# Test bat (cat alternative with syntax highlighting)
bat /etc/passwd

# Test zoxide (cd alternative)
z /etc  # First time will fail
cd /etc
cd /
z etc   # Should work now

# Test fzf (fuzzy finder)
find /etc -type f | fzf
```

### 7. Test Shell Environment
```bash
# Check if zoxide is initialized
cat ~/.profile | grep zoxide

# Check COLORTERM
echo $COLORTERM

# Test if profile loads correctly
ash -l -c 'echo $COLORTERM'
```

### 8. Test Claude Code Installation (Optional)
```bash
# Install Claude Code
/root/wsl-alpine-claude-code.sh --native

# Or copy the installer
wget https://raw.githubusercontent.com/jchidley/WSL_Alpine_build/main/wsl-alpine-claude-code.sh
chmod +x wsl-alpine-claude-code.sh
./wsl-alpine-claude-code.sh

# Test Claude Code
claude --version

# Test with Max subscription
claude login

# Test dangerous permissions flag (for containers)
claude --dangerously-skip-permissions --version
```

### 9. Test User Creation
```bash
# Check current user setup
cat /etc/wsl.conf

# The setup script should have created a user
# Check if it exists
id $USER

# Test sudo access
su - $USER
sudo apk update
```

### 10. Performance Tests
```bash
# Check image size
du -sh /

# Check memory usage
free -h

# List all installed packages
apk list --installed | wc -l
```

## Known Issues to Check

1. **First boot setup**: Verify /root/.setup-complete exists
2. **Repository access**: Ensure both main/community/testing repos work
3. **Network**: Ensure /etc/network/interfaces exists for Docker
4. **Permissions**: All user files should be owned by the user, not root

## Cleanup

```bash
# Exit WSL
exit

# From Windows/PowerShell, remove test distribution
wsl.exe --unregister alpine-test-TIMESTAMP

# Or for the default name
wsl.exe --unregister alpine-wsl
```