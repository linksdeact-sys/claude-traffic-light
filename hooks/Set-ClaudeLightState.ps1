param(
    [ValidateSet('green','yellow','blue')]
    [string]$Color = 'blue'
)
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stateFile = Join-Path $root 'state.txt'
$eventFile = Join-Path $root 'last-hook-event.jsonl'
if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }
$inputJson = [Console]::In.ReadToEnd()
$actualColor = $Color
try {
    if (-not [string]::IsNullOrWhiteSpace($inputJson)) {
        $event = $inputJson | ConvertFrom-Json -ErrorAction Stop
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
Set-Content -LiteralPath $stateFile -Value $state -Encoding ASCII
try {
    $row = [ordered]@{
        time = (Get-Date).ToString('o')
        color = $actualColor
        state = $state
        requestedColor = $Color
        input = $inputJson
    } | ConvertTo-Json -Compress -Depth 8
    Add-Content -LiteralPath $eventFile -Value $row -Encoding UTF8
} catch {}
exit 0
