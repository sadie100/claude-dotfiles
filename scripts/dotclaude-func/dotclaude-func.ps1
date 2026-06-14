# dotclaude shell function — dot-sourced from PowerShell profile
# $env:DOTCLAUDE_DIR must be set before sourcing this file

function dotclaude {
    if (-not $env:DOTCLAUDE_DIR) {
        Write-Host "Error: DOTCLAUDE_DIR is not set" -ForegroundColor Red
        return
    }
    $d = $env:DOTCLAUDE_DIR
    if ($args[0] -in @('--help', '-h', 'help')) {
        Write-Host "Usage: dotclaude <command> [options]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  sync              Sync dotfiles (git add, commit, push)"
        Write-Host "  pull              git pull --rebase --autostash + apply repo's mcp-servers.json to ~/.claude.json"
        Write-Host "  mcp-sync          ~/.claude.json mcpServers -> repo mcp-servers.json (secrets stripped)"
        Write-Host "  mcp-pull          repo mcp-servers.json -> ~/.claude.json (machine tokens preserved)"
        Write-Host "  open              Open dotfiles directory in file explorer"
        Write-Host "  code              Open dotfiles directory in editor linked to 'code'"
        Write-Host "  settings [--ed]   Edit settings.json (--vim, --vi, --nano, --code, --notepad)"
        Write-Host "  unlink            Detach ~/.claude from dotfiles (symlinks -> real copies)"
        Write-Host "  help, --help, -h  Show this help message"
        Write-Host "  <git-command>     Any other argument is passed to git"
    } elseif ($args[0] -eq 'sync') {
        node "$d\scripts\harness-sync\harness-sync.mjs"
    } elseif ($args[0] -eq 'mcp-sync') {
        node "$d\scripts\mcp-sync\mcp-sync.mjs" sync
    } elseif ($args[0] -eq 'mcp-pull') {
        node "$d\scripts\mcp-sync\mcp-sync.mjs" pull
    } elseif ($args[0] -eq 'pull') {
        # --rebase: cleanly absorb force-pushed history rewrites (old commits
        #   drop as empty). --autostash: tolerate uncommitted changes.
        git -C $d pull --rebase --autostash @($args | Select-Object -Skip 1)
        if ($LASTEXITCODE -eq 0) {
            node "$d\scripts\mcp-sync\mcp-sync.mjs" pull
        }
    } elseif ($args[0] -eq 'open') {
        explorer.exe $d
    } elseif ($args[0] -eq 'code') {
        if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
            Write-Host "Error: 'code' command not found in PATH" -ForegroundColor Red
            return
        }
        & code $d
    } elseif ($args[0] -eq 'settings') {
        $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
        switch ($args[1]) {
            '--vim'     { $editor = 'vim' }
            '--vi'      { $editor = 'vi' }
            '--nano'    { $editor = 'nano' }
            '--code'    { $editor = 'code' }
            '--notepad' { $editor = 'notepad' }
        }
        & $editor "$d\settings.json"
    } elseif ($args[0] -eq 'unlink') {
        & "$d\scripts\unlink\unlink.ps1"
    } else {
        git -C $d @args
    }
}
