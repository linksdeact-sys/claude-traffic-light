$ClaudeArgs = @($args)

function Find-ClaudeExe {
    $commands = @(Get-Command claude.exe -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        if ($command.Source -and (Test-Path -LiteralPath $command.Source)) {
            return $command.Source
        }
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

    throw "Cannot find claude.exe. Install Claude Code first, then run install.ps1 again."
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $root "config.json"
$config = $null
if (Test-Path -LiteralPath $configPath) {
    try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json } catch {}
}

$realClaude = if ($config -and $config.RealClaudePath) { [string]$config.RealClaudePath } else { Find-ClaudeExe }
$lightVbs = Join-Path $root "StartClaudeLight.vbs"
$workspace = if ($config -and $config.Workspace) {
    [string]$config.Workspace
} elseif (Test-Path -LiteralPath "D:\") {
    "D:\Claude Code"
} else {
    Join-Path $env:USERPROFILE "Claude Code"
}
$stateFile = Join-Path $root "state.txt"
$debugFile = Join-Path $root "latest-debug.log"
$ownerPidFile = Join-Path $root "owner.pid"

function Stop-ClaudeLight {
    try {
        Get-CimInstance Win32_Process -Filter "name='powershell.exe'" |
            Where-Object {
                $_.ProcessId -ne $PID -and
                $_.CommandLine -and
                $_.CommandLine -match '(?i)-File\s+.*ClaudeTrafficLight\.ps1'
            } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}
}

if (-not (Test-Path -LiteralPath $workspace)) { New-Item -ItemType Directory -Force -Path $workspace | Out-Null }
if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }

Set-Content -LiteralPath $stateFile -Value "RUNNING" -Encoding ASCII
Set-Content -LiteralPath $ownerPidFile -Value $PID -Encoding ASCII
if (Test-Path -LiteralPath $debugFile) { Remove-Item -LiteralPath $debugFile -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $lightVbs) { Start-Process wscript.exe -WindowStyle Hidden -ArgumentList @($lightVbs) | Out-Null }

Set-Location -LiteralPath $workspace
$code = 0
try {
    & $realClaude @ClaudeArgs --debug-file $debugFile
    $code = $LASTEXITCODE
} finally {
    Set-Content -LiteralPath $stateFile -Value "DONE" -Encoding ASCII
    if (Test-Path -LiteralPath $ownerPidFile) { Remove-Item -LiteralPath $ownerPidFile -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 250
    Stop-ClaudeLight
}
exit $code
