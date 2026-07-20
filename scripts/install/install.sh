#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
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
        # base 키 순서를 그대로 유지 (충돌 시 base 우선, 배열은 합집합)
        for k in base:
            if k in over:
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
            else:
                result[k] = base[k]
        # over 에만 있는 키는 뒤에 추가 (기존 순서 보존)
        for k in over:
            if k not in base:
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

# --- mcp-servers.json: merge into ~/.claude.json (mcpServers key only) ---
node "$DOTFILES_DIR/scripts/mcp-sync/mcp-sync.mjs" pull

# --- Skills: absorb existing + directory symlink ---
SKILLS_TARGET="$CLAUDE_DIR/skills"
SKILLS_SOURCE="$DOTFILES_DIR/skills"
SKILLS_BACKUP="$CLAUDE_DIR/skills.bak"

if [ -L "$SKILLS_TARGET" ]; then
  echo "[skip]   $SKILLS_TARGET (already linked)"
else
  # Absorb existing skills into dotfiles repo
  if [ -d "$SKILLS_TARGET" ]; then
    # .ignore is a container, not a single skill: reconcile each sub-skill by
    # name instead of comparing the whole folder as one unit. Handled outside
    # the loop below because its glob does not match dot-directories.
    if [ -d "$SKILLS_TARGET/.ignore" ]; then
      mkdir -p "$SKILLS_SOURCE/.ignore"
      for sub in "$SKILLS_TARGET/.ignore/"*/; do
        [ -d "$sub" ] || continue
        subname="$(basename "$sub")"
        repo_sub="$SKILLS_SOURCE/.ignore/$subname"

        if [ -d "$repo_sub" ]; then
          echo "[skip]   .ignore/$subname already exists in dotfiles, backing up local copy"
          mkdir -p "$SKILLS_BACKUP/.ignore"
          mv "$sub" "$SKILLS_BACKUP/.ignore/$subname"
        else
          echo "[absorb] $sub -> $repo_sub"
          cp -r "$sub" "$repo_sub"
        fi
      done
    fi

    for skill in "$SKILLS_TARGET/"*/; do
      [ -d "$skill" ] || continue
      name="$(basename "$skill")"

      repo_skill="$SKILLS_SOURCE/$name"

      if [ -d "$repo_skill" ]; then
        echo "[skip]   $name already exists in dotfiles, backing up local copy"
        mkdir -p "$SKILLS_BACKUP"
        mv "$skill" "$SKILLS_BACKUP/$name"
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

# --- Agents & Commands: absorb existing + directory symlink ---
for subdir in agents; do
  target="$CLAUDE_DIR/$subdir"
  source="$DOTFILES_DIR/$subdir"

  # Ensure source exists in repo
  mkdir -p "$source"

  if [ -L "$target" ]; then
    echo "[skip]   $target (already linked)"
    continue
  fi

  if [ -d "$target" ]; then
    for item in "$target"/*; do
      [ -e "$item" ] || continue
      name="$(basename "$item")"
      repo_item="$source/$name"

      if [ -e "$repo_item" ]; then
        echo "[skip]   $name already exists in dotfiles $subdir, backing up local copy"
        mv "$item" "${item}.bak"
      else
        echo "[absorb] $item -> $repo_item"
        cp -r "$item" "$repo_item"
      fi
    done
    rm -rf "$target"
  fi

  ln -s "$source" "$target"
  echo "[link]   $target -> $source"
done

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

# Register dotclaude in shell profile.
#   DOTCLAUDE_DIR must be exported where a NON-interactive login zsh can read it,
#   because that's the shell Claude Code uses to run hooks/tools — it sources
#   .zshenv but skips .zshrc (interactive-only). Putting the export in .zshrc
#   left DOTCLAUDE_DIR empty in hooks launched from GUI editors (e.g. VSCode),
#   which silently broke harness-sync/auto-push. So:
#     - export DOTCLAUDE_DIR  -> ~/.zshenv        (env, every zsh invocation)
#     - source dotclaude-func -> interactive rc   (functions/aliases)
DOTCLAUDE_SOURCE_MARKER="# dotclaude-start"
ENV_BLOCK="$DOTCLAUDE_SOURCE_MARKER
export DOTCLAUDE_DIR=\"$DOTFILES_DIR\"
# dotclaude-end"
FUNC_BLOCK="$DOTCLAUDE_SOURCE_MARKER
source \"\$DOTCLAUDE_DIR/scripts/dotclaude-func/dotclaude-func.sh\"
# dotclaude-end"

# Idempotently replace a marked dotclaude block in $1 with the content in $2.
write_dotclaude_block() {
  local file="$1" block="$2"
  touch "$file"
  if grep -qF "$DOTCLAUDE_SOURCE_MARKER" "$file"; then
    sed -i.bak "/# dotclaude-start/,/# dotclaude-end/d" "$file"
  fi
  printf '\n%s\n' "$block" >> "$file"
}

if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  # zsh: env in .zshenv (read by CC's non-interactive login zsh), funcs in .zshrc
  write_dotclaude_block "$HOME/.zshenv" "$ENV_BLOCK"
  write_dotclaude_block "$HOME/.zshrc" "$FUNC_BLOCK"
  echo "[env]    Exported DOTCLAUDE_DIR in ~/.zshenv (read by Claude Code hook shell)"
  echo "[alias]  Registered dotclaude in ~/.zshrc"
  echo ""
  echo "Done! Restart your shell (or Claude Code) to pick up DOTCLAUDE_DIR."
elif [ -f "$HOME/.bashrc" ]; then
  # bash: keep both in one profile (bash has no .zshenv equivalent)
  write_dotclaude_block "$HOME/.bashrc" "$DOTCLAUDE_SOURCE_MARKER
export DOTCLAUDE_DIR=\"$DOTFILES_DIR\"
source \"\$DOTCLAUDE_DIR/scripts/dotclaude-func/dotclaude-func.sh\"
# dotclaude-end"
  echo "[alias]  Registered dotclaude in ~/.bashrc"
  echo ""
  echo "Done! Run 'source ~/.bashrc' or restart your shell to use 'dotclaude'."
else
  echo ""
  echo "Done! Could not detect shell profile. Add DOTCLAUDE_DIR to your shell env manually:"
  echo "$ENV_BLOCK"
  echo "$FUNC_BLOCK"
fi

# Make sync script executable
chmod +x "$DOTFILES_DIR/scripts/dotfiles-sync/dotfiles-sync.sh"

# --- Sync dotfiles repo if there are changes ---
if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
  echo ""
  echo "[sync]   Pushing merged changes..."
  node "$DOTFILES_DIR/scripts/harness-sync/harness-sync.mjs"
  echo "[sync]   Done"
fi

echo ""
