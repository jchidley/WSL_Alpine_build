# Development Module (Minimal)

The development module provides a minimal set of modern development tools focused on essential CLI utilities.

## What it includes

### Editor
- **Helix** - Modern modal editor with built-in LSP support

### Modern CLI Tools
- **fd** - Fast and user-friendly alternative to find
- **bat** - Cat clone with syntax highlighting
- **ripgrep (rg)** - Blazingly fast grep alternative
- **fzf** - Command-line fuzzy finder
- **zoxide** - Smarter cd command that learns your habits
- **tree** - Directory listing in tree format

## Configuration

### Helix Editor
- Gruvbox dark theme
- Relative line numbers
- Auto-save enabled
- Tree-sitter grammars for syntax highlighting
- Mouse support enabled


## Aliases

The module sets up modern tool aliases:
- `cat` → `bat`
- `find` → `fd`
- `grep` → `rg`
- `vim`/`vi` → `hx`

## Custom Functions

### mkcd
Create directory and change into it:
```bash
mkcd my-new-project
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


## Usage Tips

1. Use `z` (zoxide) instead of `cd` for smart directory navigation
2. Pipe any command to `bat` for syntax highlighting
3. Use `rg` for fast code searching across projects
4. Press Ctrl+R for fuzzy command history search (via fzf)