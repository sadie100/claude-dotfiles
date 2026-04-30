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
        Write-Host "  open              Open dotfiles directory in file explorer"
        Write-Host "  settings [--ed]   Edit settings.json (--vim, --vi, --nano, --code, --notepad)"
        Write-Host "  help, --help, -h  Show this help message"
        Write-Host "  <git-command>     Any other argument is passed to git"
    } elseif ($args[0] -eq 'sync') {
        if (-not (git -C $d status --porcelain)) { Write-Host "No changes"; return }
        git -C $d add -A
        $changed = (git -C $d diff --cached --name-only) -join ", "
        git -C $d commit -m "sync: $changed" --no-gpg-sign 2>$null
        $b = git -C $d branch --show-current
        if (-not (git -C $d push origin $b 2>$null)) {
            git -C $d pull --rebase origin $b 2>$null
            git -C $d push origin $b 2>$null
        }
    } elseif ($args[0] -eq 'open') {
        explorer.exe $d
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
    } else {
        git -C $d @args
    }
}
