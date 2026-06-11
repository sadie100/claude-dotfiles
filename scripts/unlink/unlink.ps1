param()

$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"

Write-Host "=== Claude Code Dotfiles Unlink ===" -ForegroundColor Cyan
Write-Host "Repo (preserved): $DotfilesDir"
Write-Host "Target:           $ClaudeDir"
Write-Host ""
Write-Host "Detaches ~/.claude from the dotfiles repo:"
Write-Host "  - symlinks (settings.json, CLAUDE.md, skills, agents) -> real copies"
Write-Host "  - strips repo-coupled hooks (DOTCLAUDE_DIR) from settings.json"
Write-Host "  - removes DOTCLAUDE_DIR env var + dotclaude function from profile"
Write-Host "The repo folder and GitHub remote are left untouched."
Write-Host ""
$confirm = Read-Host "Detach this machine from dotfiles? [y/N]"
if ($confirm -notmatch '^[yY]') {
    Write-Host "Aborted."
    exit
}
Write-Host ""

# --- 1. symlinks -> real copies + strip hooks (cross-platform worker) ---
node "$DotfilesDir\scripts\unlink\unlink.mjs"

# --- 2. Remove DOTCLAUDE_DIR user environment variable ---
[Environment]::SetEnvironmentVariable("DOTCLAUDE_DIR", $null, "User")
Write-Host "[env]    Removed DOTCLAUDE_DIR user environment variable"

# --- 3. Remove dotclaude block from PowerShell profile ---
$ProfilePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $ProfilePath) {
    $ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($ProfileContent -match "# dotclaude-start") {
        $ProfileContent = $ProfileContent -replace "(?ms)# dotclaude-start.*?# dotclaude-end\r?\n?", ""
        Set-Content -Path $ProfilePath -Value $ProfileContent.TrimEnd()
        Write-Host "[clean]  Removed dotclaude block from $ProfilePath"
    } else {
        Write-Host "[skip]   No dotclaude block in $ProfilePath"
    }
} else {
    Write-Host "[skip]   PowerShell profile not found"
}

Write-Host ""
Write-Host "Done. ~/.claude is now standalone." -ForegroundColor Green
Write-Host "The repo at $DotfilesDir and its GitHub remote are untouched."
Write-Host "Open a new shell for the env var / function removal to take effect."
Write-Host "To re-link later, re-run scripts\install\install.ps1."
