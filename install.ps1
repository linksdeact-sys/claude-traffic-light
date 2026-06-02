param(
    [string]$InstallDir,
    [string]$Workspace,
    [switch]$NoHooks,
    [switch]$NoProfile
)

$ErrorActionPreference = "Stop"
$rawBase = "https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main"

if (-not $InstallDir) {
    if (Test-Path -LiteralPath "D:\") { $InstallDir = "D:\ClaudeTrafficLight" }
    else { $InstallDir = Join-Path $env:LOCALAPPDATA "ClaudeTrafficLight" }
}
if (-not $Workspace) {
    if (Test-Path -LiteralPath "D:\") { $Workspace = "D:\Claude Code" }
    else { $Workspace = Join-Path $env:USERPROFILE "Claude Code" }
}

function Write-Step([string]$message) {
    Write-Host "[ClaudeTrafficLight] $message"
}

function Find-ClaudeExe {
    param([string]$SkipDir)

    $commands = @()
    $commands += @(Get-Command claude.exe -All -ErrorAction SilentlyContinue)
    $commands += @(Get-Command claude -All -ErrorAction SilentlyContinue)

    foreach ($command in $commands) {
        if (-not $command.Source) { continue }
        if ([IO.Path]::GetExtension($command.Source) -ne ".exe") { continue }
        if ($SkipDir -and $command.Source.StartsWith($SkipDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (Test-Path -LiteralPath $command.Source) { return $command.Source }
    }

    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe",
        "$env:LOCALAPPDATA\Programs\Claude\claude.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetRoot) {
        $match = Get-ChildItem -LiteralPath $wingetRoot -Directory -Filter "Anthropic.ClaudeCode*" -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "claude.exe" } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
        if ($match) { return $match }
    }

    throw "Cannot find claude.exe. Install Claude Code first, then run this installer again."
}

function Copy-Or-DownloadFile {
    param(
        [string]$RelativePath,
        [string]$DestinationRoot,
        [string]$SourceRoot
    )

    $destination = Join-Path $DestinationRoot $RelativePath
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }

    if ($SourceRoot -and (Test-Path -LiteralPath (Join-Path $SourceRoot $RelativePath))) {
        Copy-Item -LiteralPath (Join-Path $SourceRoot $RelativePath) -Destination $destination -Force
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $urlPath = $RelativePath -replace "\\", "/"
    Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/$urlPath" -OutFile $destination
}

function Add-UserPath {
    param([string]$PathToAdd)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($userPath -split ";" | Where-Object { $_ })
    $exists = $false
    foreach ($part in $parts) {
        if ($part.TrimEnd("\") -ieq $PathToAdd.TrimEnd("\")) { $exists = $true; break }
    }
    if (-not $exists) {
        $newPath = if ($userPath) { "$PathToAdd;$userPath" } else { $PathToAdd }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
    if (($env:Path -split ";") -notcontains $PathToAdd) {
        $env:Path = "$PathToAdd;$env:Path"
    }
}

function Update-ProfileWrapper {
    param([string]$CmdPath)

    $profiles = @(
        (Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
        (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
    )

    $block = @"
# >>> Claude Traffic Light >>>
function claude {
    & "$CmdPath" @args
}
# <<< Claude Traffic Light <<<
"@

    $patterns = @(
        "(?s)# >>> Claude Traffic Light >>>.*?# <<< Claude Traffic Light <<<\s*",
        "(?s)# >>> Claude traffic light wrapper >>>.*?# <<< Claude traffic light wrapper <<<\s*"
    )

    foreach ($profilePath in $profiles) {
        $dir = Split-Path -Parent $profilePath
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $text = if (Test-Path -LiteralPath $profilePath) { Get-Content -LiteralPath $profilePath -Raw } else { "" }
        foreach ($pattern in $patterns) { $text = [regex]::Replace($text, $pattern, "") }
        $text = $text.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
        Set-Content -LiteralPath $profilePath -Value $text -Encoding UTF8
    }
}

function New-HookCommand {
    param(
        [string]$ScriptPath,
        [string]$Color
    )
    if ($Color) {
        return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $Color"
    }
    return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
}

function Remove-OldTrafficLightHookEntries {
    param($EventItems)

    $result = @()
    foreach ($item in @($EventItems)) {
        if (-not $item) { continue }
        if (-not ($item.PSObject.Properties.Name -contains "hooks")) {
            $result += $item
            continue
        }

        $keptHooks = @()
        foreach ($hook in @($item.hooks)) {
            $command = if ($hook -and ($hook.PSObject.Properties.Name -contains "command")) { [string]$hook.command } else { "" }
            if ($command -notmatch "ClaudeTrafficLight") { $keptHooks += $hook }
        }

        if ($keptHooks.Count -gt 0) {
            $item.hooks = @($keptHooks)
            $result += $item
        }
    }
    return @($result)
}

function Add-ClaudeHook {
    param(
        $HooksObject,
        [string]$EventName,
        [string]$Command,
        [bool]$Async
    )

    $existing = @()
    if ($HooksObject.PSObject.Properties.Name -contains $EventName) {
        $existing = Remove-OldTrafficLightHookEntries $HooksObject.$EventName
    }

    $hook = [ordered]@{
        type = "command"
        command = $Command
        timeout = 5
    }
    if ($Async) { $hook["async"] = $true }

    $entry = [ordered]@{ hooks = @($hook) }
    $value = @($existing) + @($entry)

    if ($HooksObject.PSObject.Properties.Name -contains $EventName) {
        $HooksObject.$EventName = $value
    } else {
        $HooksObject | Add-Member -MemberType NoteProperty -Name $EventName -Value $value
    }
}

function Install-ClaudeHooks {
    param([string]$InstallRoot)

    $settingsDir = Join-Path $HOME ".claude"
    $settingsPath = Join-Path $settingsDir "settings.json"
    if (-not (Test-Path -LiteralPath $settingsDir)) { New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null }

    if (Test-Path -LiteralPath $settingsPath) {
        $backupPath = "$settingsPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    } else {
        $settings = [pscustomobject]@{}
    }

    if (-not ($settings.PSObject.Properties.Name -contains "hooks") -or -not $settings.hooks) {
        $settings | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{}) -Force
    }

    $setState = Join-Path $InstallRoot "hooks\Set-ClaudeLightState.ps1"
    $permission = Join-Path $InstallRoot "hooks\ClaudePermissionHook.ps1"

    Add-ClaudeHook $settings.hooks "SessionStart" (New-HookCommand $setState "blue") $true
    Add-ClaudeHook $settings.hooks "UserPromptSubmit" (New-HookCommand $setState "green") $true
    Add-ClaudeHook $settings.hooks "PreToolUse" (New-HookCommand $setState "green") $true
    Add-ClaudeHook $settings.hooks "Notification" (New-HookCommand $setState "yellow") $true
    Add-ClaudeHook $settings.hooks "PermissionRequest" (New-HookCommand $permission "") $false
    Add-ClaudeHook $settings.hooks "Stop" (New-HookCommand $setState "blue") $true
    Add-ClaudeHook $settings.hooks "StopFailure" (New-HookCommand $setState "blue") $true
    Add-ClaudeHook $settings.hooks "SessionEnd" (New-HookCommand $setState "blue") $true

    $settings | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

Write-Step "Installing to $InstallDir"
$sourceRoot = if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "ClaudeTrafficLight.ps1"))) { $PSScriptRoot } else { $null }
$files = @(
    "install.ps1",
    "README.md",
    "ClaudeTrafficLight.ps1",
    "Start-ClaudeWithLight.ps1",
    "StartClaudeLight.vbs",
    "Stop-ClaudeLights.ps1",
    "claude.cmd",
    "doctor.ps1",
    "uninstall.ps1",
    "claude-settings-hooks.example.json",
    "hooks\Set-ClaudeLightState.ps1",
    "hooks\ClaudePermissionHook.ps1"
)

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $Workspace | Out-Null
foreach ($file in $files) {
    Copy-Or-DownloadFile -RelativePath $file -DestinationRoot $InstallDir -SourceRoot $sourceRoot
}

$realClaude = Find-ClaudeExe -SkipDir $InstallDir
$config = [ordered]@{
    InstallDir = $InstallDir
    Workspace = $Workspace
    RealClaudePath = $realClaude
    InstalledAt = (Get-Date).ToString("o")
}
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $InstallDir "config.json") -Encoding UTF8

Add-UserPath $InstallDir
if (-not $NoProfile) { Update-ProfileWrapper (Join-Path $InstallDir "claude.cmd") }
if (-not $NoHooks) { Install-ClaudeHooks $InstallDir }

Set-Content -LiteralPath (Join-Path $InstallDir "state.txt") -Value "DONE" -Encoding ASCII

Write-Step "Done."
Write-Host ""
Write-Host "Install dir : $InstallDir"
Write-Host "Workspace   : $Workspace"
Write-Host "Claude exe  : $realClaude"
Write-Host ""
Write-Host "Restart PowerShell, then run: claude"
Write-Host "For diagnostics, run: powershell -ExecutionPolicy Bypass -File `"$InstallDir\doctor.ps1`""
