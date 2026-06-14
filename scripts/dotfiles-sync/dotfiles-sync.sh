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
BRANCH="$(git branch --show-current)"
if ! git push origin "$BRANCH" 2>/dev/null; then
  # Non-interactive editors so the rebase can never pause waiting for input.
  if GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true \
       git pull --rebase origin "$BRANCH" 2>/dev/null; then
    git push origin "$BRANCH" 2>/dev/null || true  # offline: retry next sync
  else
    # Real conflict: abort so we never leave a half-finished rebase behind.
    git rebase --abort 2>/dev/null || true
  fi
fi
