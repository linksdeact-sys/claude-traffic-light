$ClaudeArgs = @($args)

$realClaude = "C:\Users\pxy\AppData\Local\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe"
$root = "D:\ClaudeTrafficLight"
$lightVbs = Join-Path $root "StartClaudeLight.vbs"
$workspace = "D:\Claude Code"
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
