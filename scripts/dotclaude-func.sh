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
      echo "  open              Open dotfiles directory in file explorer"
      echo "  settings [--ed]   Edit settings.json (--vim, --vi, --nano, --code, --notepad)"
      echo "  help, --help, -h  Show this help message"
      echo "  <git-command>     Any other argument is passed to git"
      ;;
    sync)
      bash "$DOTCLAUDE_DIR/scripts/dotfiles-sync.sh"
      ;;
    open)
      if [[ "$OSTYPE" == darwin* ]]; then
        open "$DOTCLAUDE_DIR"
      else
        xdg-open "$DOTCLAUDE_DIR"
      fi
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
