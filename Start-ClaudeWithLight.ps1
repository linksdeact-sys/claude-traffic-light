$ClaudeArgs = @($args)

$realClaude = "C:\Users\pxy\AppData\Local\Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe"
$root = "D:\ClaudeTrafficLight"
$lightVbs = Join-Path $root "StartClaudeLight.vbs"
$workspace = "D:\Claude Code"
$stateFile = Join-Path $root "state.txt"
$debugFile = Join-Path $root "latest-debug.log"

if (-not (Test-Path -LiteralPath $workspace)) { New-Item -ItemType Directory -Force -Path $workspace | Out-Null }
if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }

Set-Content -LiteralPath $stateFile -Value "RUNNING" -Encoding ASCII
if (Test-Path -LiteralPath $debugFile) { Remove-Item -LiteralPath $debugFile -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $lightVbs) { Start-Process wscript.exe -WindowStyle Hidden -ArgumentList @($lightVbs) | Out-Null }

Set-Location -LiteralPath $workspace
& $realClaude @ClaudeArgs --debug-file $debugFile
$code = $LASTEXITCODE
Set-Content -LiteralPath $stateFile -Value "DONE" -Encoding ASCII
exit $code
