Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File ""D:\ClaudeTrafficLight\ClaudeTrafficLight.ps1""", 0, False
