$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stateFile = Join-Path $root 'state.txt'
$eventFile = Join-Path $root 'last-hook-event.jsonl'
if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }
$inputJson = [Console]::In.ReadToEnd()
try {
    $event = $inputJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    Set-Content -LiteralPath $stateFile -Value 'ACTION' -Encoding ASCII
    exit 0
}

$toolName = ''
if ($event.PSObject.Properties.Name -contains 'tool_name') { $toolName = [string]$event.tool_name }
elseif ($event.PSObject.Properties.Name -contains 'toolName') { $toolName = [string]$event.toolName }
elseif ($event.PSObject.Properties.Name -contains 'tool') { $toolName = [string]$event.tool }

$command = ''
if ($event.PSObject.Properties.Name -contains 'tool_input' -and $event.tool_input -and ($event.tool_input.PSObject.Properties.Name -contains 'command')) { $command = [string]$event.tool_input.command }
elseif ($event.PSObject.Properties.Name -contains 'input' -and $event.input -and ($event.input.PSObject.Properties.Name -contains 'command')) { $command = [string]$event.input.command }
elseif ($event.PSObject.Properties.Name -contains 'command') { $command = [string]$event.command }

$dangerous = @(
    '(?i)\brm\s+.*(-rf|-fr)',
    '(?i)\bRemove-Item\b.*(-Recurse|-r) ',
    '(?i)\bdel\b.*(/s|/q)',
    '(?i)\brmdir\b.*(/s)',
    '(?i)\bformat\b',
    '(?i)\bdiskpart\b',
    '(?i)\breg\s+delete\b',
    '(?i)\bgit\s+reset\s+--hard\b',
    '(?i)\bgit\s+clean\s+-fd',
    '(?i)\bshutdown\b',
    '(?i)\bStop-Process\b.*(-Force|-Id)',
    '(?i)\btaskkill\b',
    '(?i)\.ssh',
    '(?i)AppData\\Roaming',
    '(?i)Windows\\System32'
)

$isDangerous = $false
foreach ($pattern in $dangerous) {
    if ($command -match $pattern) { $isDangerous = $true; break }
}

$safeTools = @('Read','LS','Glob','Grep','Edit','MultiEdit','Write','WebFetch','WebSearch')
$allow = (($safeTools -contains $toolName) -or ($toolName -eq 'Bash')) -and (-not $isDangerous)

if ($allow) {
    Set-Content -LiteralPath $stateFile -Value 'RUNNING' -Encoding ASCII
    $logState = 'RUNNING'
    $logColor = 'green'
} else {
    Set-Content -LiteralPath $stateFile -Value 'ACTION' -Encoding ASCII
    $logState = 'ACTION'
    $logColor = 'yellow'
}

try {
    $row = [ordered]@{
        time = (Get-Date).ToString('o')
        color = $logColor
        state = $logState
        hook = 'PermissionRequest'
        toolName = $toolName
        command = $command
        input = $inputJson
    } | ConvertTo-Json -Compress -Depth 8
    Add-Content -LiteralPath $eventFile -Value $row -Encoding UTF8
} catch {}

if ($allow) {
    '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","message":"Auto-approved by local ClaudeTrafficLight hook"}}}'
}
exit 0
