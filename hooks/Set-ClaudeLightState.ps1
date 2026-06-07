param(
    [ValidateSet('green','yellow','blue')]
    [string]$Color = 'blue'
)

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
        [string]$HookName
    )

    $stateFile = Join-Path $Root "state.txt"
    Set-Content -LiteralPath $stateFile -Value $State -Encoding ASCII

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
            $record | Add-Member -NotePropertyName lastHook -NotePropertyValue $HookName -Force
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
$actualColor = $Color
$hookName = ""

try {
    if (-not [string]::IsNullOrWhiteSpace($inputJson)) {
        $event = $inputJson | ConvertFrom-Json -ErrorAction Stop
        if ($event.PSObject.Properties.Name -contains "hook_event_name") { $hookName = [string]$event.hook_event_name }
        if ($event.hook_event_name -eq 'Notification') {
            if ($event.notification_type -eq 'permission_prompt') { $actualColor = 'yellow' }
            elseif ($event.notification_type -eq 'idle_prompt') { $actualColor = 'blue' }
        }
    }
} catch {}

$state = switch ($actualColor) {
    'green' { 'RUNNING' }
    'yellow' { 'ACTION' }
    default { 'DONE' }
}

Set-InstanceState -Root $root -State $state -Color $actualColor -HookName $hookName

try {
    $row = [ordered]@{
        time = (Get-Date).ToString('o')
        instanceId = $env:CLAUDE_TRAFFIC_LIGHT_INSTANCE_ID
        color = $actualColor
        state = $state
        requestedColor = $Color
        input = $inputJson
    } | ConvertTo-Json -Compress -Depth 8
    Add-Content -LiteralPath $eventFile -Value $row -Encoding UTF8
} catch {}
exit 0
