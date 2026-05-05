#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== Claude Code Dotfiles Installer ==="
echo "Source: $DOTFILES_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# --- settings.json: deep merge then symlink ---
SETTINGS_SOURCE="$DOTFILES_DIR/settings.json"
SETTINGS_TARGET="$CLAUDE_DIR/settings.json"

if [ -L "$SETTINGS_TARGET" ]; then
  echo "[skip]   $SETTINGS_TARGET (already linked)"
else
  if [ -f "$SETTINGS_TARGET" ]; then
    # Deep merge: dotfiles as base, user's unique keys/array entries added
    # jq: base * override for objects, arrays are unioned
    merged=$(python3 -c '
import json, sys

def deep_merge(base, over):
    if isinstance(base, dict) and isinstance(over, dict):
        result = {}
        for k in set(list(base.keys()) + list(over.keys())):
            if k in base and k in over:
                if isinstance(base[k], dict) and isinstance(over[k], dict):
                    result[k] = deep_merge(base[k], over[k])
                elif isinstance(base[k], list) and isinstance(over[k], list):
                    seen = []
                    for item in base[k] + over[k]:
                        if item not in seen:
                            seen.append(item)
                    result[k] = seen
                else:
                    result[k] = base[k]
            elif k in base:
                result[k] = base[k]
            else:
                result[k] = over[k]
        return result
    return base

with open(sys.argv[1]) as f:
    base = json.load(f)
with open(sys.argv[2]) as f:
    over = json.load(f)

print(json.dumps(deep_merge(base, over), indent=2, ensure_ascii=False))
' "$SETTINGS_SOURCE" "$SETTINGS_TARGET")

    echo "$merged" > "$SETTINGS_SOURCE"
    echo "[merge]  Merged user settings into dotfiles settings.json"

    # Backup original
    echo "[backup] $SETTINGS_TARGET -> ${SETTINGS_TARGET}.bak"
    mv "$SETTINGS_TARGET" "${SETTINGS_TARGET}.bak"
  fi

  ln -s "$SETTINGS_SOURCE" "$SETTINGS_TARGET"
  echo "[link]   $SETTINGS_TARGET -> $SETTINGS_SOURCE"
fi

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

# --- CLAUDE.md: symlink ---
DOTFILES_CLAUDE="$DOTFILES_DIR/CLAUDE.md"
TARGET_CLAUDE="$CLAUDE_DIR/CLAUDE.md"

if [ -L "$TARGET_CLAUDE" ]; then
  echo "[skip]   $TARGET_CLAUDE (already linked)"
else
  if [ -f "$TARGET_CLAUDE" ]; then
    echo "[backup] $TARGET_CLAUDE -> ${TARGET_CLAUDE}.bak"
    mv "$TARGET_CLAUDE" "${TARGET_CLAUDE}.bak"
  fi
  ln -s "$DOTFILES_CLAUDE" "$TARGET_CLAUDE"
  echo "[link]   $TARGET_CLAUDE -> $DOTFILES_CLAUDE"
fi

# Register dotclaude in shell profile (source from repo, not inline)
DOTCLAUDE_SOURCE_MARKER="# dotclaude-start"
DOTCLAUDE_SOURCE_BLOCK="$DOTCLAUDE_SOURCE_MARKER
export DOTCLAUDE_DIR=\"$DOTFILES_DIR\"
source \"\$DOTCLAUDE_DIR/scripts/dotclaude-func.sh\"
# dotclaude-end"

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
fi

if [ -n "$SHELL_PROFILE" ]; then
  # Remove old inline function if present
  if grep -qF "function dotclaude" "$SHELL_PROFILE"; then
    sed -i.bak "/function dotclaude/,/^}/d" "$SHELL_PROFILE"
    echo "[clean]  Removed old inline dotclaude function from $SHELL_PROFILE"
  fi

  # Remove old source block if present, then re-add
  if grep -qF "$DOTCLAUDE_SOURCE_MARKER" "$SHELL_PROFILE"; then
    sed -i.bak "/# dotclaude-start/,/# dotclaude-end/d" "$SHELL_PROFILE"
  fi

  echo "" >> "$SHELL_PROFILE"
  echo "$DOTCLAUDE_SOURCE_BLOCK" >> "$SHELL_PROFILE"
  echo "[alias]  Registered dotclaude in $SHELL_PROFILE (sourced from repo)"
  echo ""
  echo "Done! Run 'source $SHELL_PROFILE' or restart your shell to use 'dotclaude'."
else
  echo ""
  echo "Done! Could not detect shell profile. Manually add these lines to your profile:"
  echo "$DOTCLAUDE_SOURCE_BLOCK"
fi

# Make sync script executable
chmod +x "$DOTFILES_DIR/scripts/dotfiles-sync.sh"

# --- Sync dotfiles repo if there are changes ---
if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
  echo ""
  echo "[sync]   Pushing merged changes..."
  bash "$DOTFILES_DIR/scripts/dotfiles-sync.sh"
  echo "[sync]   Done"
fi

echo ""
