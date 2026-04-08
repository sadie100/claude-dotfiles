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

# --- Skills: absorb existing + directory symlink ---
$SkillsTarget = Join-Path $ClaudeDir "skills"
$SkillsSource = Join-Path $DotfilesDir "skills"

if ((Test-Path $SkillsTarget) -and (Get-Item $SkillsTarget).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    Write-Host "[skip]   $SkillsTarget (already linked)"
} else {
    # Absorb existing skills into dotfiles repo
    if (Test-Path $SkillsTarget) {
        foreach ($skill in (Get-ChildItem -Path $SkillsTarget -Directory -ErrorAction SilentlyContinue)) {
            $repoSkill = Join-Path $SkillsSource $skill.Name

            if (Test-Path $repoSkill) {
                Write-Host "[skip]   $($skill.Name) already exists in dotfiles, backing up local copy"
                Move-Item -Path $skill.FullName -Destination "$($skill.FullName).bak" -Force
            } else {
                Write-Host "[absorb] $($skill.FullName) -> $repoSkill"
                Copy-Item -Path $skill.FullName -Destination $repoSkill -Recurse
            }
        }
        # Remove original directory (absorbed contents are in repo now)
        Remove-Item -Path $SkillsTarget -Recurse -Force
    }

    # Symlink entire skills directory
    New-Item -ItemType SymbolicLink -Path $SkillsTarget -Target $SkillsSource -Force | Out-Null
    Write-Host "[link]   $SkillsTarget -> $SkillsSource"
}

# --- CLAUDE.md: merge with marker block ---
$Marker = "# >>> claude-dotfiles >>>"
$MarkerEnd = "# <<< claude-dotfiles <<<"
$DotfilesClaude = Join-Path $DotfilesDir "CLAUDE.md"
$TargetClaude = Join-Path $ClaudeDir "CLAUDE.md"
$DotfilesContent = Get-Content $DotfilesClaude -Raw

if (Test-Path $TargetClaude) {
    $existing = Get-Content $TargetClaude -Raw
    if ($existing -match [regex]::Escape($Marker)) {
        $pattern = [regex]::Escape($Marker) + "[\s\S]*?" + [regex]::Escape($MarkerEnd)
        $replacement = "$Marker`n$DotfilesContent`n$MarkerEnd"
        $updated = [regex]::Replace($existing, $pattern, $replacement)
        Set-Content -Path $TargetClaude -Value $updated -NoNewline
        Write-Host "[merge]  Updated managed block in $TargetClaude"
    } else {
        $block = "`n$Marker`n$DotfilesContent`n$MarkerEnd`n"
        Add-Content -Path $TargetClaude -Value $block -NoNewline
        Write-Host "[merge]  Appended dotfiles content to $TargetClaude"
    }
} else {
    $block = "$Marker`n$DotfilesContent`n$MarkerEnd`n"
    Set-Content -Path $TargetClaude -Value $block -NoNewline
    Write-Host "[merge]  Created $TargetClaude with dotfiles content"
}

# --- Plugins: merge installed_plugins.json ---
$DotfilesPlugins = Join-Path $DotfilesDir "plugins" "installed_plugins.json"
$TargetPlugins = Join-Path $ClaudeDir "plugins" "installed_plugins.json"

if (Test-Path $TargetPlugins) {
    # Remove symlink first if exists
    if ((Get-Item $TargetPlugins).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        $content = Get-Content $TargetPlugins -Raw
        Remove-Item $TargetPlugins -Force
        Set-Content -Path $TargetPlugins -Value $content -NoNewline
        Write-Host "[fix]    Removed symlink, restored as regular file"
    }

    $existing = Get-Content $TargetPlugins -Raw | ConvertFrom-Json
    $dotfiles = Get-Content $DotfilesPlugins -Raw | ConvertFrom-Json

    # Merge: add dotfiles plugins that don't exist in target
    foreach ($key in $dotfiles.plugins.PSObject.Properties.Name) {
        if (-not $existing.plugins.PSObject.Properties[$key]) {
            $existing.plugins | Add-Member -NotePropertyName $key -NotePropertyValue $dotfiles.plugins.$key
            Write-Host "[merge]  Added plugin: $key"
        }
    }

    $existing | ConvertTo-Json -Depth 10 | Set-Content -Path $TargetPlugins
    Write-Host "[merge]  Merged plugins: kept existing + added dotfiles entries"
} else {
    Copy-Item -Path $DotfilesPlugins -Destination $TargetPlugins
    Write-Host "[copy]   $DotfilesPlugins -> $TargetPlugins"
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
