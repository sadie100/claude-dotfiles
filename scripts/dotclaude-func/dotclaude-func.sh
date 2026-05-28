#!/usr/bin/env bash
# dotclaude shell function — sourced from shell profile
# $DOTCLAUDE_DIR must be set before sourcing this file

function dotclaude() {
  if [ -z "$DOTCLAUDE_DIR" ]; then
    echo "Error: DOTCLAUDE_DIR is not set" >&2
    return 1
  fi
  case "$1" in
    --help|-h|help)
      echo "Usage: dotclaude <command> [options]"
      echo ""
      echo "Commands:"
      echo "  sync              Sync dotfiles (git add, commit, push)"
      echo "  pull              git pull + apply repo's mcp-servers.json to ~/.claude.json"
      echo "  mcp-sync          ~/.claude.json mcpServers -> repo mcp-servers.json (secrets stripped)"
      echo "  mcp-pull          repo mcp-servers.json -> ~/.claude.json (machine tokens preserved)"
      echo "  open              Open dotfiles directory in file explorer"
      echo "  code              Open dotfiles directory in editor linked to 'code'"
      echo "  settings [--ed]   Edit settings.json (--vim, --vi, --nano, --code, --notepad)"
      echo "  help, --help, -h  Show this help message"
      echo "  <git-command>     Any other argument is passed to git"
      ;;
    sync)
      node "$DOTCLAUDE_DIR/scripts/harness-sync/harness-sync.mjs"
      ;;
    mcp-sync)
      node "$DOTCLAUDE_DIR/scripts/mcp-sync/mcp-sync.mjs" sync
      ;;
    mcp-pull)
      node "$DOTCLAUDE_DIR/scripts/mcp-sync/mcp-sync.mjs" pull
      ;;
    pull)
      git -C "$DOTCLAUDE_DIR" pull "${@:2}" \
        && node "$DOTCLAUDE_DIR/scripts/mcp-sync/mcp-sync.mjs" pull
      ;;
    open)
      if [[ "$OSTYPE" == darwin* ]]; then
        open "$DOTCLAUDE_DIR"
      else
        xdg-open "$DOTCLAUDE_DIR"
      fi
      ;;
    code)
      if ! command -v code >/dev/null 2>&1; then
        echo "Error: 'code' command not found in PATH" >&2
        return 1
      fi
      code "$DOTCLAUDE_DIR"
      ;;
    settings)
      local editor="${EDITOR:-vi}"
      case "$2" in
        --vim) editor="vim" ;;
        --vi) editor="vi" ;;
        --nano) editor="nano" ;;
        --code) editor="code" ;;
        --notepad) editor="notepad" ;;
      esac
      $editor "$DOTCLAUDE_DIR/settings.json"
      ;;
    *)
      git -C "$DOTCLAUDE_DIR" "$@"
      ;;
  esac
}
