#!/usr/bin/env bash
# Exposes skills under skills/.ignore/ to Claude Code by symlinking each one
# to the top level of skills/ (Claude Code only loads skills/<name>/SKILL.md).
# Symlink names are ignored via .git/info/exclude (local-only, never committed)
# so company/machine-specific skill names don't leak into the repo.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_DIR="$DOTFILES_DIR/skills"
EXCLUDE_FILE="$DOTFILES_DIR/.git/info/exclude"

# Remove dangling symlinks left over from deleted .ignore skills
for link in "$SKILLS_DIR"/*; do
  if [ -L "$link" ] && [[ "$(readlink "$link")" == .ignore/* ]] && [ ! -e "$link" ]; then
    echo "[clean]  ${link#"$DOTFILES_DIR/"} (target removed)"
    rm "$link"
  fi
done

[ -d "$SKILLS_DIR/.ignore" ] || exit 0

for skill in "$SKILLS_DIR/.ignore/"*/; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  link="$SKILLS_DIR/$name"

  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "[skip]   skills/$name exists and is not a symlink"
    continue
  fi
  if [ ! -L "$link" ]; then
    ln -s ".ignore/$name" "$link"
    echo "[link]   skills/$name -> .ignore/$name"
  fi
  if ! grep -qxF "skills/$name" "$EXCLUDE_FILE" 2>/dev/null; then
    echo "skills/$name" >> "$EXCLUDE_FILE"
    echo "[ignore] skills/$name added to .git/info/exclude"
  fi
done
