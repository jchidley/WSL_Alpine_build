# Development Module

The development module provides a comprehensive set of modern development tools and utilities.

## What it includes

### Editors
- **Helix** - Modern modal editor with built-in LSP support
- **Vim** - Classic vi improved editor
- **Nano** - Simple and user-friendly editor

### Modern CLI Tools
- **fd** - Fast and user-friendly alternative to find
- **bat** - Cat clone with syntax highlighting
- **ripgrep (rg)** - Blazingly fast grep alternative
- **fzf** - Command-line fuzzy finder
- **zoxide** - Smarter cd command that learns your habits
- **htop** - Interactive process viewer
- **ncdu** - NCurses disk usage analyzer
- **tree** - Directory listing in tree format
- **jq/yq** - Command-line JSON/YAML processors

### Development Tools
- **Git** with Git LFS support
- **tmux** - Terminal multiplexer
- **curl/wget** - HTTP clients
- **rsync** - Fast file transfer

### Programming Languages
- **Python 3** with pip
- **Go** programming language
- **Rust** with cargo

## Configuration

### Helix Editor
- Gruvbox dark theme
- Relative line numbers
- Auto-save enabled
- Tree-sitter grammars for syntax highlighting
- Mouse support enabled

### Git
- Default branch: main
- Editor: helix
- Useful aliases pre-configured

### tmux
- Prefix key: Ctrl-a
- Mouse support enabled
- Intuitive pane splitting (| and -)
- Alt+Arrow keys for pane navigation

## Aliases

The module sets up modern tool aliases:
- `cat` → `bat`
- `find` → `fd`
- `grep` → `rg`
- `vim`/`vi` → `hx`
- `top` → `htop`
- `du` → `ncdu`

## Custom Functions

### mkcd
Create directory and change into it:
```bash
mkcd my-new-project
```

### extract
Extract any archive format:
```bash
extract archive.tar.gz
extract file.zip
```

### proj
Find and navigate to projects using fzf:
```bash
proj  # Search from current directory
proj ~/projects  # Search in specific directory
```

### fe
Find and edit files with fzf:
```bash
fe  # Find and edit files
fe test  # Find files matching "test"
```

### fbr
Interactive git branch switcher:
```bash
fbr  # Select and checkout git branch
```

## Usage Tips

1. Use `z` (zoxide) instead of `cd` for smart directory navigation
2. Pipe any command to `bat` for syntax highlighting
3. Use `rg` for fast code searching across projects
4. Press Ctrl+R for fuzzy command history search (via fzf)