$needle = 'ClaudeTrafficLight.ps1'
Get-CimInstance Win32_Process -Filter "name='powershell.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*$needle*" -and $_.CommandLine -match '(?i)-File' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
