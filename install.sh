#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

FILES=(
  "settings.json"
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

# --- Skills: absorb existing + directory symlink ---
SKILLS_TARGET="$CLAUDE_DIR/skills"
SKILLS_SOURCE="$DOTFILES_DIR/skills"

if [ -L "$SKILLS_TARGET" ]; then
  echo "[skip]   $SKILLS_TARGET (already linked)"
else
  # Absorb existing skills into dotfiles repo
  if [ -d "$SKILLS_TARGET" ]; then
    for skill in "$SKILLS_TARGET/"*/; do
      [ -d "$skill" ] || continue
      name="$(basename "$skill")"
      repo_skill="$SKILLS_SOURCE/$name"

      if [ -d "$repo_skill" ]; then
        echo "[skip]   $name already exists in dotfiles, backing up local copy"
        mv "$skill" "${skill%/}.bak"
      else
        echo "[absorb] $skill -> $repo_skill"
        cp -r "$skill" "$repo_skill"
      fi
    done
    # Remove original directory (absorbed contents are in repo now)
    rm -rf "$SKILLS_TARGET"
  fi

  # Symlink entire skills directory
  ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
  echo "[link]   $SKILLS_TARGET -> $SKILLS_SOURCE"
fi

# --- CLAUDE.md: merge with marker block ---
MARKER="# >>> claude-dotfiles >>>"
MARKER_END="# <<< claude-dotfiles <<<"
DOTFILES_CLAUDE="$DOTFILES_DIR/CLAUDE.md"
TARGET_CLAUDE="$CLAUDE_DIR/CLAUDE.md"

if [ -f "$TARGET_CLAUDE" ] && grep -qF "$MARKER" "$TARGET_CLAUDE"; then
  # Replace existing managed block
  tmp="$(mktemp)"
  awk -v m="$MARKER" -v me="$MARKER_END" '
    $0 == m { skip=1; next }
    $0 == me { skip=0; next }
    !skip { print }
  ' "$TARGET_CLAUDE" > "$tmp"
  {
    cat "$tmp"
    echo "$MARKER"
    cat "$DOTFILES_CLAUDE"
    echo "$MARKER_END"
  } > "$TARGET_CLAUDE"
  rm "$tmp"
  echo "[merge]  Updated managed block in $TARGET_CLAUDE"
else
  if [ -f "$TARGET_CLAUDE" ]; then
    echo "" >> "$TARGET_CLAUDE"
  fi
  {
    echo "$MARKER"
    cat "$DOTFILES_CLAUDE"
    echo "$MARKER_END"
  } >> "$TARGET_CLAUDE"
  echo "[merge]  Appended dotfiles content to $TARGET_CLAUDE"
fi

# --- Plugins: merge installed_plugins.json ---
DOTFILES_PLUGINS="$DOTFILES_DIR/plugins/installed_plugins.json"
TARGET_PLUGINS="$CLAUDE_DIR/plugins/installed_plugins.json"

if [ -f "$TARGET_PLUGINS" ] && [ ! -L "$TARGET_PLUGINS" ] && [ -f "$DOTFILES_PLUGINS" ]; then
  # Merge: existing + dotfiles (dotfiles wins on conflict)
  python3 -c "
import json, sys
with open(sys.argv[1]) as f: existing = json.load(f)
with open(sys.argv[2]) as f: dotfiles = json.load(f)
merged = existing.copy()
merged['plugins'] = {**existing.get('plugins', {}), **dotfiles.get('plugins', {})}
with open(sys.argv[1], 'w') as f: json.dump(merged, f, indent=2)
" "$TARGET_PLUGINS" "$DOTFILES_PLUGINS"
  echo "[merge]  Merged plugins: kept existing + added dotfiles entries"
elif [ -L "$TARGET_PLUGINS" ]; then
  echo "[skip]   $TARGET_PLUGINS (is a symlink, removing and merging)"
  real_content="$(cat "$TARGET_PLUGINS")"
  rm "$TARGET_PLUGINS"
  echo "$real_content" > "$TARGET_PLUGINS"
  python3 -c "
import json, sys
with open(sys.argv[1]) as f: existing = json.load(f)
with open(sys.argv[2]) as f: dotfiles = json.load(f)
merged = existing.copy()
merged['plugins'] = {**existing.get('plugins', {}), **dotfiles.get('plugins', {})}
with open(sys.argv[1], 'w') as f: json.dump(merged, f, indent=2)
" "$TARGET_PLUGINS" "$DOTFILES_PLUGINS"
  echo "[merge]  Merged plugins after removing symlink"
elif [ -f "$DOTFILES_PLUGINS" ]; then
  cp "$DOTFILES_PLUGINS" "$TARGET_PLUGINS"
  echo "[copy]   $DOTFILES_PLUGINS -> $TARGET_PLUGINS"
fi

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
