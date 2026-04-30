param()

# Auto-elevate to admin (needed for symlink creation)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path $PSScriptRoot -Parent
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"

Write-Host "=== Claude Code Dotfiles Installer ===" -ForegroundColor Cyan
Write-Host "Source: $DotfilesDir"
Write-Host "Target: $ClaudeDir"
Write-Host ""

# Ensure target directories exist
New-Item -ItemType Directory -Path (Join-Path $ClaudeDir "plugins") -Force | Out-Null

# --- settings.json: deep merge then symlink ---
function Merge-JsonDeep {
    param($Base, $Override)
    $result = $Base.PSObject.Copy()
    foreach ($prop in $Override.PSObject.Properties) {
        $key = $prop.Name
        $overVal = $prop.Value
        if ($result.PSObject.Properties[$key]) {
            $baseVal = $result.$key
            if ($baseVal -is [PSCustomObject] -and $overVal -is [PSCustomObject]) {
                $result.$key = Merge-JsonDeep $baseVal $overVal
            } elseif ($baseVal -is [System.Collections.IEnumerable] -and $baseVal -isnot [string] -and
                      $overVal -is [System.Collections.IEnumerable] -and $overVal -isnot [string]) {
                $merged = [System.Collections.Generic.List[object]]::new()
                foreach ($item in $baseVal) { $merged.Add($item) }
                foreach ($item in $overVal) {
                    if ($merged -notcontains $item) { $merged.Add($item) }
                }
                $result.$key = $merged.ToArray()
            }
            # scalar conflicts: base (dotfiles) wins — no overwrite
        } else {
            $result | Add-Member -NotePropertyName $key -NotePropertyValue $overVal
        }
    }
    return $result
}

$SettingsSource = Join-Path $DotfilesDir "settings.json"
$SettingsTarget = Join-Path $ClaudeDir "settings.json"

if ((Test-Path $SettingsTarget) -and (Get-Item $SettingsTarget).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    Write-Host "[skip]   $SettingsTarget (already linked)"
} else {
    if ((Test-Path $SettingsTarget) -and -not (Get-Item $SettingsTarget).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        $existingSettings = Get-Content $SettingsTarget -Raw | ConvertFrom-Json
        $dotfilesSettings = Get-Content $SettingsSource -Raw | ConvertFrom-Json

        # Deep merge: dotfiles base + user's unique keys/array entries
        $merged = Merge-JsonDeep $dotfilesSettings $existingSettings
        $json = $merged | ConvertTo-Json -Depth 10
        # ConvertTo-Json uses 4-space indent; normalize to 2-space
        $json = ($json -split "`n" | ForEach-Object {
            if ($_ -match '^( +)') {
                (' ' * [math]::Floor($Matches[1].Length / 2)) + $_.TrimStart()
            } else { $_ }
        }) -join "`n"
        $json | Set-Content -Path $SettingsSource
        Write-Host "[merge]  Merged user settings into dotfiles settings.json"

        # Backup original
        $backup = "${SettingsTarget}.bak"
        Write-Host "[backup] $SettingsTarget -> $backup"
        Move-Item -Path $SettingsTarget -Destination $backup -Force
    }

    New-Item -ItemType SymbolicLink -Path $SettingsTarget -Target $SettingsSource -Force | Out-Null
    Write-Host "[link]   $SettingsTarget -> $SettingsSource"
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

# --- CLAUDE.md: symlink ---
$DotfilesClaude = Join-Path $DotfilesDir "CLAUDE.md"
$TargetClaude = Join-Path $ClaudeDir "CLAUDE.md"

if ((Test-Path $TargetClaude) -and (Get-Item $TargetClaude).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    Write-Host "[skip]   $TargetClaude (already linked)"
} else {
    if (Test-Path $TargetClaude) {
        $backup = "${TargetClaude}.bak"
        Write-Host "[backup] $TargetClaude -> $backup"
        Move-Item -Path $TargetClaude -Destination $backup -Force
    }
    New-Item -ItemType SymbolicLink -Path $TargetClaude -Target $DotfilesClaude -Force | Out-Null
    Write-Host "[link]   $TargetClaude -> $DotfilesClaude"
}

# --- Plugins: merge installed_plugins.json ---
$DotfilesPlugins = Join-Path (Join-Path $DotfilesDir "plugins") "installed_plugins.json"
$TargetPlugins = Join-Path (Join-Path $ClaudeDir "plugins") "installed_plugins.json"

if (!(Test-Path $DotfilesPlugins)) {
    Write-Host "[skip]   No plugins definition in dotfiles"
} elseif (Test-Path $TargetPlugins) {
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
$FuncBody = @"

function dotclaude {
    if (`$args[0] -in @('--help', '-h', 'help')) {
        Write-Host "Usage: dotclaude <command> [options]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  sync              Sync dotfiles (git add, commit, push)"
        Write-Host "  open              Open dotfiles directory in file explorer"
        Write-Host "  settings [--ed]   Edit settings.json (--vim, --vi, --nano, --code, --notepad)"
        Write-Host "  help, --help, -h  Show this help message"
        Write-Host "  <git-command>     Any other argument is passed to git"
    } elseif (`$args[0] -eq 'sync') {
        `$d = "$DotfilesDir"
        if (-not (git -C `$d status --porcelain)) { Write-Host "No changes"; return }
        git -C `$d add -A
        `$changed = (git -C `$d diff --cached --name-only) -join ", "
        git -C `$d commit -m "sync: `$changed" --no-gpg-sign 2>`$null
        `$b = git -C `$d branch --show-current
        if (-not (git -C `$d push origin `$b 2>`$null)) {
            git -C `$d pull --rebase origin `$b 2>`$null
            git -C `$d push origin `$b 2>`$null
        }
    } elseif (`$args[0] -eq 'open') {
        explorer.exe "$DotfilesDir"
    } elseif (`$args[0] -eq 'settings') {
        `$editor = if (`$env:EDITOR) { `$env:EDITOR } else { 'notepad' }
        switch (`$args[1]) {
            '--vim'     { `$editor = 'vim' }
            '--vi'      { `$editor = 'vi' }
            '--nano'    { `$editor = 'nano' }
            '--code'    { `$editor = 'code' }
            '--notepad' { `$editor = 'notepad' }
        }
        & `$editor "$DotfilesDir\settings.json"
    } else {
        git -C "$DotfilesDir" @args
    }
}
"@

# Explicitly target the user's profile (admin elevation can change $PROFILE)
$ProfilePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

if (!(Test-Path $ProfilePath)) {
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
}

$ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -match "function dotclaude") {
    # Remove old function block (handles nested braces)
    $lines = $ProfileContent -split "`n"
    $newLines = [System.Collections.Generic.List[string]]::new()
    $skip = $false
    $braceDepth = 0
    foreach ($line in $lines) {
        if (!$skip -and $line -match '^\s*function dotclaude') {
            $skip = $true
            $braceDepth = 0
        }
        if ($skip) {
            $braceDepth += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
            $braceDepth -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
            if ($braceDepth -le 0 -and $line -match '\}') { $skip = $false; continue }
        } else {
            $newLines.Add($line)
        }
    }
    $ProfileContent = ($newLines -join "`n").TrimEnd() + "`n" + $FuncBody
    Set-Content -Path $ProfilePath -Value $ProfileContent
    Write-Host "[alias]  Updated dotclaude function in $ProfilePath"
} else {
    Add-Content -Path $ProfilePath -Value $FuncBody
    Write-Host "[alias]  Added dotclaude function to $ProfilePath"
}

# --- Sync dotfiles repo if there are changes ---
$hasChanges = (git -C $DotfilesDir status --porcelain) -ne ""
if ($hasChanges) {
    Write-Host ""
    Write-Host "[sync]   Pushing merged changes..." -ForegroundColor Yellow
    git -C $DotfilesDir add -A
    $changed = (git -C $DotfilesDir diff --cached --name-only) -join ", "
    git -C $DotfilesDir commit -m "sync: $changed" --no-gpg-sign 2>$null
    $branch = git -C $DotfilesDir branch --show-current
    git -C $DotfilesDir push origin $branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        git -C $DotfilesDir pull --rebase origin $branch 2>$null
        git -C $DotfilesDir push origin $branch 2>$null
    }
    Write-Host "[sync]   Done" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Restart PowerShell or run '. `$PROFILE' to use 'dotclaude'." -ForegroundColor Green
Write-Host ""
