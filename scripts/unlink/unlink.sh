#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== Claude Code Dotfiles Unlink ==="
echo "Repo (preserved): $DOTFILES_DIR"
echo "Target:           $CLAUDE_DIR"
echo ""
echo "Detaches ~/.claude from the dotfiles repo:"
echo "  - symlinks (settings.json, CLAUDE.md, skills, agents) -> real copies"
echo "  - strips repo-coupled hooks (DOTCLAUDE_DIR) from settings.json"
echo "  - removes DOTCLAUDE_DIR env var + dotclaude function from profile"
echo "The repo folder and GitHub remote are left untouched."
echo ""
read -r -p "Detach this machine from dotfiles? [y/N] " confirm
case "$confirm" in
  y|Y) ;;
  *) echo "Aborted."; exit 0 ;;
esac
echo ""

# --- 1. symlinks -> real copies + strip hooks (cross-platform worker) ---
node "$DOTFILES_DIR/scripts/unlink/unlink.mjs"

# --- 2 & 3. Remove dotclaude block (incl. DOTCLAUDE_DIR export) from profile ---
removed=0
for profile in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$profile" ] && grep -qF "# dotclaude-start" "$profile"; then
    sed -i.bak "/# dotclaude-start/,/# dotclaude-end/d" "$profile"
    echo "[clean]  Removed dotclaude block from $profile"
    removed=1
  fi
done
if [ "$removed" -eq 0 ]; then
  echo "[skip]   No dotclaude block found in ~/.zshrc or ~/.bashrc"
fi

echo ""
echo "Done. ~/.claude is now standalone."
echo "The repo at $DOTFILES_DIR and its GitHub remote are untouched."
echo "Open a new shell (or 'unset DOTCLAUDE_DIR') for changes to take effect."
echo "To re-link later, re-run scripts/install/install.sh."
