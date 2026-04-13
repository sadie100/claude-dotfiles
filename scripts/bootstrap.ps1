# Auto-elevate to admin (needed for symlink creation)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptContent = Invoke-RestMethod "https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap.ps1"
    $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $tempFile -Value $scriptContent
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$tempFile`""
    exit
}

$ErrorActionPreference = "Stop"

$RepoUrl = if ($env:REPO_URL) { $env:REPO_URL } else { "https://github.com/sadie100/claude-dotfiles.git" }
$DotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $env:USERPROFILE "claude-dotfiles" }

Write-Host "=== Claude Code Dotfiles Bootstrap ===" -ForegroundColor Cyan

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[error] git is not installed. Please install git first." -ForegroundColor Red
    exit 1
}

# Clone or pull
if (Test-Path (Join-Path $DotfilesDir ".git")) {
    Write-Host "[pull]   $DotfilesDir (already cloned)"
    git -C $DotfilesDir pull --rebase 2>$null
} else {
    Write-Host "[clone]  $RepoUrl -> $DotfilesDir"
    git clone $RepoUrl $DotfilesDir
}

# Run installer
Write-Host ""
& "$DotfilesDir\scripts\install.ps1"
