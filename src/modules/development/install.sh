#!/usr/bin/env bash
# Development module installation script

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=src/lib/common.sh
source "${PROJECT_ROOT}/src/lib/common.sh"
# shellcheck source=src/lib/package.sh
source "${PROJECT_ROOT}/src/lib/package.sh"

# Check ROOTFS_DIR is set
if [[ -z "${ROOTFS_DIR:-}" ]]; then
    log_error "ROOTFS_DIR not set"
    exit 1
fi

log_info "Installing development module..."

# Install editor packages
log_progress "Installing editors..."
if ! install_packages "$ROOTFS_DIR" helix vim nano; then
    log_error "Failed to install editors"
    exit 1
fi

# Install modern CLI tools
log_progress "Installing modern CLI tools..."
if ! install_packages "$ROOTFS_DIR" fd bat zoxide fzf ripgrep tree htop ncdu jq; then
    log_error "Failed to install CLI tools"
    exit 1
fi

# Install yq from testing
log_progress "Installing yq..."
if ! run_apk_in_rootfs "$ROOTFS_DIR" add --no-cache yq@testing; then
    log_warning "Failed to install yq from testing repository"
fi

# Install development tools
log_progress "Installing development tools..."
if ! install_packages "$ROOTFS_DIR" git git-lfs curl wget rsync tmux; then
    log_error "Failed to install development tools"
    exit 1
fi

# Install programming languages
log_progress "Installing programming languages..."
if ! install_packages "$ROOTFS_DIR" python3 py3-pip go rust cargo; then
    log_warning "Some programming languages failed to install"
fi

# Install tree-sitter grammars for Helix
log_progress "Installing Helix syntax highlighting..."
grammars=(
    "tree-sitter-bash"
    "tree-sitter-c"
    "tree-sitter-cpp"
    "tree-sitter-css"
    "tree-sitter-go"
    "tree-sitter-html"
    "tree-sitter-javascript"
    "tree-sitter-json"
    "tree-sitter-markdown@testing"
    "tree-sitter-python"
    "tree-sitter-rust"
    "tree-sitter-typescript"
    "tree-sitter-yaml"
)

for grammar in "${grammars[@]}"; do
    if ! run_apk_in_rootfs "$ROOTFS_DIR" add --no-cache "$grammar" 2>/dev/null; then
        log_verbose "Grammar not available: $grammar"
    fi
done

# Configure Helix
log_progress "Configuring Helix editor..."
mkdir -p "$ROOTFS_DIR/home/wsluser/.config/helix"
cat > "$ROOTFS_DIR/home/wsluser/.config/helix/config.toml" << 'EOF'
theme = "gruvbox_dark_hard"

[editor]
line-number = "relative"
mouse = true
rulers = [80, 120]
auto-save = true
completion-trigger-len = 2
idle-timeout = 250
preview-completion-insert = false

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.file-picker]
hidden = false
follow-links = true
deduplicate-links = true
parents = true
ignore = true
git-ignore = true
git-global = true
git-exclude = true

[editor.indent-guides]
render = true
character = "╎"
skip-levels = 1

[editor.statusline]
left = ["mode", "spinner", "version-control", "file-name", "file-modification-indicator"]
center = ["position", "position-percentage", "total-line-numbers"]
right = ["diagnostics", "selections", "register", "file-encoding", "file-line-ending", "file-type"]

[editor.lsp]
display-messages = true
display-inlay-hints = true

[editor.whitespace.render]
space = "none"
tab = "all"
newline = "none"

[editor.whitespace.characters]
space = "·"
nbsp = "⍽"
tab = "→"
newline = "⏎"
tabpad = "·"

[keys.normal]
space.w = ":w"
space.q = ":q"
EOF

# Copy Helix config to root user
cp -r "$ROOTFS_DIR/home/wsluser/.config/helix" "$ROOTFS_DIR/root/.config/"

# Configure Git
log_progress "Configuring Git..."
cat > "$ROOTFS_DIR/home/wsluser/.gitconfig" << 'EOF'
[user]
    name = WSL User
    email = wsluser@localhost

[core]
    editor = hx
    autocrlf = input
    whitespace = fix,-indent-with-non-tab,trailing-space,cr-at-eol

[color]
    ui = auto

[push]
    default = simple
    autoSetupRemote = true

[pull]
    rebase = false

[init]
    defaultBranch = main

[alias]
    st = status -sb
    co = checkout
    br = branch
    ci = commit
    df = diff
    dfs = diff --staged
    lg = log --oneline --graph --decorate
    lga = log --oneline --graph --decorate --all
    last = log -1 HEAD
    unstage = reset HEAD --
    amend = commit --amend --no-edit
    pushf = push --force-with-lease
EOF

# Configure tmux
log_progress "Configuring tmux..."
cat > "$ROOTFS_DIR/home/wsluser/.tmux.conf" << 'EOF'
# Set prefix to Ctrl-a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Enable mouse
set -g mouse on

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Enable 256 colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"

# Status bar
set -g status-style bg=colour235,fg=colour136
set -g status-left '#[fg=colour235,bg=colour252,bold] #S #[fg=colour252,bg=colour235,nobold]'
set -g status-right '#[fg=colour252,bg=colour235]#[fg=colour235,bg=colour252,bold] %H:%M '
set -g window-status-format '#[fg=colour180,bg=colour235] #I:#W '
set -g window-status-current-format '#[fg=colour235,bg=colour39]#[fg=colour235,bg=colour39,noreverse,bold] #I:#W #[fg=colour39,bg=colour235,nobold]'

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on
EOF

# Add shell configuration for development tools
cat >> "$ROOTFS_DIR/home/wsluser/.bashrc" << 'EOF'

# Development tools configuration
export EDITOR=hx
export VISUAL=hx
export PAGER="bat --style=plain"

# Initialize zoxide
eval "$(zoxide init bash)"

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Bat configuration
export BAT_THEME="gruvbox-dark"

# Aliases for modern tools
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias ps='procs'
alias du='ncdu'
alias top='htop'
alias vim='hx'
alias vi='hx'

# Git aliases
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# Development functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"   ;;
            *.tar.gz)    tar xzf "$1"   ;;
            *.bz2)       bunzip2 "$1"   ;;
            *.rar)       unrar x "$1"   ;;
            *.gz)        gunzip "$1"    ;;
            *.tar)       tar xf "$1"    ;;
            *.tbz2)      tar xjf "$1"   ;;
            *.tgz)       tar xzf "$1"   ;;
            *.zip)       unzip "$1"     ;;
            *.Z)         uncompress "$1";;
            *.7z)        7z x "$1"      ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick project search with fzf
proj() {
    local dir
    dir=$(fd --type d --hidden --exclude .git . "${1:-.}" | fzf +m) && cd "$dir"
}

# Search and edit files with fzf
fe() {
    local files
    IFS=$'\n' files=($(fzf --query="$1" --multi --select-1 --exit-0))
    [[ -n "$files" ]] && ${EDITOR:-hx} "${files[@]}"
}

# Git branch selection with fzf
fbr() {
    local branches branch
    branches=$(git --no-pager branch -vv) &&
    branch=$(echo "$branches" | fzf +m) &&
    git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}
EOF

# Create development info script
cat > "$ROOTFS_DIR/etc/development-info" << 'EOF'
#!/bin/bash
# Display development tools information

echo "╔══════════════════════════════════════════════╗"
echo "║      Development Tools Module                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Editors:"
echo "  • Helix (hx) - Modern terminal editor"
echo "  • Vim - Classic editor"
echo "  • Nano - Simple editor"
echo ""
echo "Modern CLI Tools:"
echo "  • fd - Fast file finder (replaces find)"
echo "  • bat - Cat with syntax highlighting"
echo "  • ripgrep (rg) - Fast grep replacement"
echo "  • fzf - Fuzzy finder"
echo "  • zoxide - Smart cd command"
echo "  • htop - Interactive process viewer"
echo "  • ncdu - NCurses disk usage"
echo "  • jq/yq - JSON/YAML processors"
echo ""
echo "Development Tools:"
echo "  • Git with LFS support"
echo "  • tmux - Terminal multiplexer"
echo "  • Python 3 with pip"
echo "  • Go programming language"
echo "  • Rust with cargo"
echo ""
echo "Useful aliases:"
echo "  • cat → bat"
echo "  • find → fd"
echo "  • grep → rg"
echo "  • vim/vi → hx"
echo ""
echo "Custom functions:"
echo "  • mkcd - Make directory and cd into it"
echo "  • extract - Extract any archive"
echo "  • proj - Project finder with fzf"
echo "  • fe - Find and edit files"
echo "  • fbr - Git branch switcher"
echo ""
EOF
chmod +x "$ROOTFS_DIR/etc/development-info"

# Add to login message
cat > "$ROOTFS_DIR/etc/development-motd" << 'EOF'

Development tools installed! Run:
  development-info - Show available tools and aliases
  hx              - Launch Helix editor

EOF

log_success "Development module installed successfully"