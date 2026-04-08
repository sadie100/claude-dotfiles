param()

# Auto-elevate to admin (needed for symlink creation)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = "Stop"

$DotfilesDir = $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"

$Files = @(
    "settings.json"
    "plugins\installed_plugins.json"
    "CLAUDE.md"
)

$Dirs = @(
    "skills"
)

Write-Host "=== Claude Code Dotfiles Installer ===" -ForegroundColor Cyan
Write-Host "Source: $DotfilesDir"
Write-Host "Target: $ClaudeDir"
Write-Host ""

# Ensure target directories exist
New-Item -ItemType Directory -Path (Join-Path $ClaudeDir "plugins") -Force | Out-Null

# Backup and symlink files
foreach ($f in $Files) {
    $target = Join-Path $ClaudeDir $f
    $source = Join-Path $DotfilesDir $f

    if ((Test-Path $target) -and -not (Get-Item $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        $backup = "${target}.bak"
        Write-Host "[backup] $target -> $backup"
        Move-Item -Path $target -Destination $backup -Force
    }

    if ((Test-Path $target) -and (Get-Item $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        Write-Host "[skip]   $target (already linked)"
    } else {
        New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
        Write-Host "[link]   $target -> $source"
    }
}

# Backup and symlink directories
foreach ($d in $Dirs) {
    $target = Join-Path $ClaudeDir $d
    $source = Join-Path $DotfilesDir $d

    if ((Test-Path $target) -and -not (Get-Item $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        $backup = "${target}.bak"
        Write-Host "[backup] $target -> $backup"
        Move-Item -Path $target -Destination $backup -Force
    }

    if ((Test-Path $target) -and (Get-Item $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        Write-Host "[skip]   $target (already linked)"
    } else {
        New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
        Write-Host "[link]   $target -> $source"
    }
}

# Register function in PowerShell profile
$FuncLine = "function dotclaude { git -C `"$DotfilesDir`" @args }"
$ProfilePath = $PROFILE.CurrentUserCurrentHost

if (!(Test-Path $ProfilePath)) {
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
}

$ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -match "function dotclaude") {
    $ProfileContent = $ProfileContent -replace "function dotclaude \{[^}]+\}", $FuncLine
    Set-Content -Path $ProfilePath -Value $ProfileContent
    Write-Host "[alias]  Updated dotclaude function in $ProfilePath"
} else {
    Add-Content -Path $ProfilePath -Value "`n$FuncLine"
    Write-Host "[alias]  Added dotclaude function to $ProfilePath"
}

Write-Host ""
Write-Host "Done! Restart PowerShell or run '. `$PROFILE' to use 'dotclaude'." -ForegroundColor Green
Write-Host ""
