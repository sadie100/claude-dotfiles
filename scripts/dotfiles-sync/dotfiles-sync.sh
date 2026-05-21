#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTCLAUDE_DIR:-${DOTFILES_DIR:-$HOME/claude-dotfiles}}"

# Exit if dotfiles repo doesn't exist
[ -d "$DOTFILES_DIR/.git" ] || exit 0

cd "$DOTFILES_DIR"

# Lockdir to prevent concurrent syncs (mkdir is atomic, portable across macOS/Linux)
LOCKDIR="$DOTFILES_DIR/.git/dotfiles-sync.lock.d"
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR"' EXIT

# Exit if no changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  exit 0
fi

# Stage all managed files (.gitignore filters to only managed files)
git add -A

# Generate commit message from changed files
CHANGED=$(git diff --cached --name-only | tr '\n' ', ' | sed 's/,$//')
git commit -m "sync: ${CHANGED}" --no-gpg-sign 2>/dev/null || exit 0

# Push with pull-rebase retry on conflict
if ! git push origin "$(git branch --show-current)" 2>/dev/null; then
  git pull --rebase origin "$(git branch --show-current)" 2>/dev/null \
    && git push origin "$(git branch --show-current)" 2>/dev/null \
    || true  # silently fail if offline or unresolvable conflict
fi
