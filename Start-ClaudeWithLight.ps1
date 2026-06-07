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

function Write-Instance {
    param(
        [string]$Path,
        [string]$State,
        [string]$Color
    )

    $now = (Get-Date).ToString("o")
    $record = [ordered]@{
        id = $sessionId
        ownerPid = $PID
        parentPid = $parentPid
        state = $State
        color = $Color
        title = $title
        workspace = $workspace
        debugFile = $debugFile
        createdAt = $createdAt
        updatedAt = $now
    }
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
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
$instancesDir = Join-Path $root "instances"
$logsDir = Join-Path $root "logs"
$sessionId = [guid]::NewGuid().ToString("N")
$instanceFile = Join-Path $instancesDir "$sessionId.json"
$debugFile = Join-Path $logsDir "debug-$sessionId.log"
$createdAt = (Get-Date).ToString("o")
$parentPid = $null
try { $parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId } catch {}

$workspaceLeaf = Split-Path -Leaf $workspace
if ([string]::IsNullOrWhiteSpace($workspaceLeaf)) { $workspaceLeaf = $workspace }
$title = "Claude $($sessionId.Substring(0, 6)) - $workspaceLeaf"

if (-not (Test-Path -LiteralPath $workspace)) { New-Item -ItemType Directory -Force -Path $workspace | Out-Null }
foreach ($dir in @($root, $instancesDir, $logsDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

Set-Content -LiteralPath $stateFile -Value "RUNNING" -Encoding ASCII
Write-Instance -Path $instanceFile -State "RUNNING" -Color "green"

$env:CLAUDE_TRAFFIC_LIGHT_ROOT = $root
$env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_ID = $sessionId
$env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_FILE = $instanceFile
$env:CLAUDE_TRAFFIC_LIGHT_OWNER_PID = [string]$PID

if (Test-Path -LiteralPath $lightVbs) { Start-Process wscript.exe -WindowStyle Hidden -ArgumentList @($lightVbs) | Out-Null }

Set-Location -LiteralPath $workspace
$code = 0
try {
    & $realClaude @ClaudeArgs --debug-file $debugFile
    $code = $LASTEXITCODE
} finally {
    Set-Content -LiteralPath $stateFile -Value "DONE" -Encoding ASCII
    if (Test-Path -LiteralPath $instanceFile) {
        Write-Instance -Path $instanceFile -State "DONE" -Color "blue"
        Start-Sleep -Milliseconds 350
        Remove-Item -LiteralPath $instanceFile -Force -ErrorAction SilentlyContinue
    }
}
exit $code
