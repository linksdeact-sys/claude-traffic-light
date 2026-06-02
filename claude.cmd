@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-ClaudeWithLight.ps1" %*
exit /b %ERRORLEVEL%
