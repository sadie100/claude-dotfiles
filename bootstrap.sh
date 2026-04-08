#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/sadie100/claude-dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/claude-dotfiles}"

echo "=== Claude Code Dotfiles Bootstrap ==="

# Check git
if ! command -v git &>/dev/null; then
  echo "[error] git is not installed. Please install git first."
  exit 1
fi

# Clone or pull
if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "[pull]   $DOTFILES_DIR (already cloned)"
  git -C "$DOTFILES_DIR" pull --rebase origin "$(git -C "$DOTFILES_DIR" branch --show-current)" 2>/dev/null || true
else
  echo "[clone]  $REPO_URL -> $DOTFILES_DIR"
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# Run installer
echo ""
bash "$DOTFILES_DIR/install.sh"
