@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\Start-ClaudeWithLight.ps1" %*
exit /b %ERRORLEVEL%
