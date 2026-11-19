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

# Warn (once per broken state) if ~/.claude entries are no longer symlinks into this repo.
# Warn only — never auto-fix, never fail the sync.
check_symlinks() {
  local marker="$DOTFILES_DIR/.git/dotfiles-sync.symlink-warned"
  local real_dir broken="" name target
  real_dir="$(pwd -P)"
  for name in settings.json CLAUDE.md skills agents; do
    target="$(readlink "$HOME/.claude/$name" 2>/dev/null || true)"
    case "$target" in
      "$DOTFILES_DIR"/*|"$real_dir"/*) ;;
      *) broken="${broken:+$broken, }$name" ;;
    esac
  done

  if [ -z "$broken" ]; then
    rm -f "$marker"
    return 0
  fi
  [ "$(cat "$marker" 2>/dev/null || true)" = "$broken" ] && return 0
  printf '%s' "$broken" > "$marker"
  local msg="dotfiles 심볼릭 링크 끊김: ~/.claude/{$broken}"
  echo "[dotfiles-sync] $msg" >&2
  node "$DOTFILES_DIR/scripts/hooks/notify.mjs" "$msg" </dev/null >/dev/null 2>&1 || true
}
check_symlinks || true

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
