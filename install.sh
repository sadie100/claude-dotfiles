#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

FILES=(
  "settings.json"
  "plugins/installed_plugins.json"
  "CLAUDE.md"
)

DIRS=(
  "skills"
)

echo "=== Claude Code Dotfiles Installer ==="
echo "Source: $DOTFILES_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

mkdir -p "$CLAUDE_DIR/plugins"

# Backup and symlink files
for f in "${FILES[@]}"; do
  target="$CLAUDE_DIR/$f"
  source="$DOTFILES_DIR/$f"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "[backup] $target -> ${target}.bak"
    mv "$target" "${target}.bak"
  fi

  if [ -L "$target" ]; then
    echo "[skip]   $target (already linked)"
  else
    ln -s "$source" "$target"
    echo "[link]   $target -> $source"
  fi
done

# Backup and symlink directories
for d in "${DIRS[@]}"; do
  target="$CLAUDE_DIR/$d"
  source="$DOTFILES_DIR/$d"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "[backup] $target -> ${target}.bak"
    mv "$target" "${target}.bak"
  fi

  if [ -L "$target" ]; then
    echo "[skip]   $target (already linked)"
  else
    ln -s "$source" "$target"
    echo "[link]   $target -> $source"
  fi
done

# Register alias in shell profile
ALIAS_LINE="alias dotclaude='git -C $DOTFILES_DIR'"

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
fi

if [ -n "$SHELL_PROFILE" ]; then
  if grep -qF "alias dotclaude=" "$SHELL_PROFILE"; then
    sed -i.bak "s|alias dotclaude=.*|$ALIAS_LINE|" "$SHELL_PROFILE"
    echo "[alias]  Updated dotclaude alias in $SHELL_PROFILE"
  else
    echo "" >> "$SHELL_PROFILE"
    echo "$ALIAS_LINE" >> "$SHELL_PROFILE"
    echo "[alias]  Added dotclaude alias to $SHELL_PROFILE"
  fi
  echo ""
  echo "Done! Run 'source $SHELL_PROFILE' or restart your shell to use 'dotclaude'."
else
  echo ""
  echo "Done! Could not detect shell profile. Manually add this to your profile:"
  echo "  $ALIAS_LINE"
fi
echo ""
