# Claude Code Module

The Claude Code module provides integration with Anthropic's Claude Code CLI for AI-assisted development.

## What it includes

- Node.js and npm (required for Claude Code)
- Installation script for Claude Code CLI
- Docker-aware wrapper for containerized environments
- Pre-configured settings optimized for Alpine
- Helper scripts and aliases

## Features

### Installation
- Deferred installation - Claude Code is not installed by default
- Run `install-claude-code` to install when needed
- Automatic installation on first use of `claude` command

### Docker Support
- `claude-docker` wrapper automatically handles Docker permissions
- Detects Docker environment and adds `--dangerously-skip-permissions` flag
- Suitable for CI/CD pipelines

### Configuration
- Default editor set to Helix (if available)
- Telemetry disabled by default
- Gruvbox dark color scheme for terminal output

## Usage

### First Time Setup
```bash
# Install Claude Code
install-claude-code

# Login to Claude (requires Claude Max subscription)
claude login

# Or set API key for programmatic access
export ANTHROPIC_API_KEY=sk-ant-...
```

### Common Commands
```bash
# Start interactive chat
claude chat

# Create new project
claude new my-project

# Get help
claude --help

# Show module information
claude-code-info
```

### Docker/CI Usage
```bash
# Use the Docker wrapper
claude-docker chat

# Or use the flag directly
claude --dangerously-skip-permissions chat
```

## Environment Variables

- `ANTHROPIC_API_KEY` - API key for authentication
- `ANTHROPIC_LOG_LEVEL` - Log level (error, warn, info, debug)
- `CLAUDE_CODE_CONFIG_DIR` - Configuration directory
- `CLAUDE_CODE_EXPERIMENTAL` - Enable experimental features

## Notes

- Claude Code requires a Claude Max subscription or API key
- The CLI is installed globally via npm when requested
- Configuration is stored in `~/.config/claude-code/`
- See `/etc/claude-code.env.example` for all environment options