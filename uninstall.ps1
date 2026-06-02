param(
    [string]$InstallDir,
    [switch]$RemoveFiles
)

$ErrorActionPreference = "Stop"
if (-not $InstallDir) {
    if ($PSScriptRoot) { $InstallDir = $PSScriptRoot }
    elseif (Test-Path -LiteralPath "D:\ClaudeTrafficLight") { $InstallDir = "D:\ClaudeTrafficLight" }
    else { $InstallDir = Join-Path $env:LOCALAPPDATA "ClaudeTrafficLight" }
}

function Write-Step([string]$message) {
    Write-Host "[ClaudeTrafficLight] $message"
}

function Stop-Light {
    Get-CimInstance Win32_Process -Filter "name='powershell.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -match '(?i)-File\s+.*ClaudeTrafficLight\.ps1' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Remove-UserPath {
    param([string]$PathToRemove)
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { return }
    $parts = @($userPath -split ";" | Where-Object {
        $_ -and ($_.TrimEnd("\") -ine $PathToRemove.TrimEnd("\"))
    })
    [Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")
}

function Remove-ProfileWrapper {
    $profiles = @(
        (Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
        (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
    )
    $patterns = @(
        "(?s)# >>> Claude Traffic Light >>>.*?# <<< Claude Traffic Light <<<\s*",
        "(?s)# >>> Claude traffic light wrapper >>>.*?# <<< Claude traffic light wrapper <<<\s*"
    )
    foreach ($profilePath in $profiles) {
        if (-not (Test-Path -LiteralPath $profilePath)) { continue }
        $text = Get-Content -LiteralPath $profilePath -Raw
        foreach ($pattern in $patterns) { $text = [regex]::Replace($text, $pattern, "") }
        Set-Content -LiteralPath $profilePath -Value $text -Encoding UTF8
    }
}

function Remove-HooksFromSettings {
    $settingsPath = Join-Path $HOME ".claude\settings.json"
    if (-not (Test-Path -LiteralPath $settingsPath)) { return }

    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if (-not ($settings.PSObject.Properties.Name -contains "hooks") -or -not $settings.hooks) { return }

    foreach ($eventName in @($settings.hooks.PSObject.Properties.Name)) {
        $newItems = @()
        foreach ($item in @($settings.hooks.$eventName)) {
            if (-not ($item.PSObject.Properties.Name -contains "hooks")) {
                $newItems += $item
                continue
            }
            $keptHooks = @()
            foreach ($hook in @($item.hooks)) {
                $command = if ($hook -and ($hook.PSObject.Properties.Name -contains "command")) { [string]$hook.command } else { "" }
                if ($command -notmatch "ClaudeTrafficLight") { $keptHooks += $hook }
            }
            if ($keptHooks.Count -gt 0) {
                $item.hooks = @($keptHooks)
                $newItems += $item
            }
        }
        $settings.hooks.$eventName = @($newItems)
    }

    $settings | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

Write-Step "Stopping light"
Stop-Light
Write-Step "Removing PATH/profile/hooks"
Remove-UserPath $InstallDir
Remove-ProfileWrapper
Remove-HooksFromSettings

if ($RemoveFiles -and (Test-Path -LiteralPath $InstallDir)) {
    Write-Step "Removing files from $InstallDir"
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
}

Write-Step "Done. Restart PowerShell."
