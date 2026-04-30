# dotfiles-sync.ps1 — Windows equivalent of dotfiles-sync.sh
# Auto-commits and pushes dotfiles changes with mutex-based locking

$ErrorActionPreference = "SilentlyContinue"

$DotfilesDir = if ($env:DOTCLAUDE_DIR) { $env:DOTCLAUDE_DIR } elseif ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $env:USERPROFILE "claude-dotfiles" }

# Exit if dotfiles repo doesn't exist
if (-not (Test-Path (Join-Path $DotfilesDir ".git"))) { exit 0 }

Set-Location $DotfilesDir

# Mutex to prevent concurrent syncs (equivalent of flock)
$mutex = $null
try {
    $mutex = [System.Threading.Mutex]::new($false, "Global\claude-dotfiles-sync")
    if (-not $mutex.WaitOne(0)) { exit 0 }

    # Exit if no changes
    git diff --quiet 2>$null
    $unstaged = $LASTEXITCODE -ne 0
    git diff --cached --quiet 2>$null
    $staged = $LASTEXITCODE -ne 0
    $untracked = git ls-files --others --exclude-standard
    if (-not $unstaged -and -not $staged -and -not $untracked) { exit 0 }

    # Stage all managed files
    git add -A

    # Generate commit message from changed files
    $changed = (git diff --cached --name-only) -join ", "
    git commit -m "sync: $changed" --no-gpg-sign 2>$null
    if ($LASTEXITCODE -ne 0) { exit 0 }

    # Push with pull-rebase retry on conflict
    $branch = git branch --show-current
    git push origin $branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        git pull --rebase origin $branch 2>$null
        git push origin $branch 2>$null
    }
} finally {
    if ($mutex) {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}
