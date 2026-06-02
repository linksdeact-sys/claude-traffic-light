param(
    [string]$InstallDir
)

$ErrorActionPreference = "SilentlyContinue"
if (-not $InstallDir) {
    if ($PSScriptRoot) { $InstallDir = $PSScriptRoot }
    elseif (Test-Path -LiteralPath "D:\ClaudeTrafficLight") { $InstallDir = "D:\ClaudeTrafficLight" }
    else { $InstallDir = Join-Path $env:LOCALAPPDATA "ClaudeTrafficLight" }
}

function Test-Ok([string]$Name, [bool]$Ok, [string]$Detail) {
    $mark = if ($Ok) { "OK " } else { "BAD" }
    Write-Host ("[{0}] {1} - {2}" -f $mark, $Name, $Detail)
}

Write-Host "Claude Traffic Light doctor"
Write-Host ""

$required = @(
    "ClaudeTrafficLight.ps1",
    "Start-ClaudeWithLight.ps1",
    "StartClaudeLight.vbs",
    "claude.cmd",
    "hooks\Set-ClaudeLightState.ps1",
    "hooks\ClaudePermissionHook.ps1"
)

Test-Ok "Install dir" (Test-Path -LiteralPath $InstallDir) $InstallDir
foreach ($file in $required) {
    $path = Join-Path $InstallDir $file
    Test-Ok $file (Test-Path -LiteralPath $path) $path
}

$configPath = Join-Path $InstallDir "config.json"
$configOk = Test-Path -LiteralPath $configPath
Test-Ok "config.json" $configOk $configPath
if ($configOk) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    Test-Ok "Claude exe" (Test-Path -LiteralPath ([string]$config.RealClaudePath)) ([string]$config.RealClaudePath)
    Test-Ok "Workspace" (Test-Path -LiteralPath ([string]$config.Workspace)) ([string]$config.Workspace)
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$inPath = $false
foreach ($part in @($userPath -split ";" | Where-Object { $_ })) {
    if ($part.TrimEnd("\") -ieq $InstallDir.TrimEnd("\")) { $inPath = $true; break }
}
Test-Ok "User PATH" $inPath "contains $InstallDir"

$profiles = @(
    (Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
)
$profileHit = $false
foreach ($profilePath in $profiles) {
    if ((Test-Path -LiteralPath $profilePath) -and ((Get-Content -LiteralPath $profilePath -Raw) -match "Claude Traffic Light")) {
        $profileHit = $true
    }
}
Test-Ok "PowerShell profile" $profileHit "wrapper function installed"

$settingsPath = Join-Path $HOME ".claude\settings.json"
$hooksOk = $false
if (Test-Path -LiteralPath $settingsPath) {
    $settingsText = Get-Content -LiteralPath $settingsPath -Raw
    $hooksOk = $settingsText -match "ClaudeTrafficLight"
}
Test-Ok "Claude hooks" $hooksOk $settingsPath

try {
    Set-Content -LiteralPath (Join-Path $InstallDir "state.txt") -Value "DONE" -Encoding ASCII
    $lightScript = Join-Path $InstallDir "ClaudeTrafficLight.ps1"
    [scriptblock]::Create((Get-Content -LiteralPath $lightScript -Raw)) | Out-Null
    Test-Ok "Light syntax" $true $lightScript
} catch {
    Test-Ok "Light syntax" $false $_.Exception.Message
}

Write-Host ""
Write-Host "If something is BAD, run install.ps1 again or open an issue with this output."
