function Get-Root {
    if ($env:CLAUDE_TRAFFIC_LIGHT_ROOT -and (Test-Path -LiteralPath $env:CLAUDE_TRAFFIC_LIGHT_ROOT)) {
        return $env:CLAUDE_TRAFFIC_LIGHT_ROOT
    }
    return Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

function Set-InstanceState {
    param(
        [string]$Root,
        [string]$State,
        [string]$Color,
        [string]$ToolName
    )

    Set-Content -LiteralPath (Join-Path $Root "state.txt") -Value $State -Encoding ASCII

    $instanceId = $env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_ID
    $instanceFile = $env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_FILE
    if (-not $instanceFile -and $instanceId) {
        $instanceFile = Join-Path (Join-Path $Root "instances") "$instanceId.json"
    }
    if (-not $instanceFile -or -not (Test-Path -LiteralPath $instanceFile)) { return }

    for ($i = 0; $i -lt 5; $i++) {
        try {
            $record = Get-Content -LiteralPath $instanceFile -Raw -ErrorAction Stop | ConvertFrom-Json
            $record | Add-Member -NotePropertyName state -NotePropertyValue $State -Force
            $record | Add-Member -NotePropertyName color -NotePropertyValue $Color -Force
            $record | Add-Member -NotePropertyName lastHook -NotePropertyValue "PermissionRequest" -Force
            $record | Add-Member -NotePropertyName lastTool -NotePropertyValue $ToolName -Force
            $record | Add-Member -NotePropertyName updatedAt -NotePropertyValue ((Get-Date).ToString("o")) -Force
            $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $instanceFile -Encoding UTF8
            return
        } catch {
            Start-Sleep -Milliseconds 40
        }
    }
}

$root = Get-Root
$eventFile = Join-Path $root 'last-hook-event.jsonl'
if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }
$inputJson = [Console]::In.ReadToEnd()
try {
    $event = $inputJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    Set-InstanceState -Root $root -State 'ACTION' -Color 'yellow' -ToolName ''
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
    Set-InstanceState -Root $root -State 'RUNNING' -Color 'green' -ToolName $toolName
    $logState = 'RUNNING'
    $logColor = 'green'
} else {
    Set-InstanceState -Root $root -State 'ACTION' -Color 'yellow' -ToolName $toolName
    $logState = 'ACTION'
    $logColor = 'yellow'
}

try {
    $row = [ordered]@{
        time = (Get-Date).ToString('o')
        instanceId = $env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_ID
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
