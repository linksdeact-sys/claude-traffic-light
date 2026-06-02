Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File """ & root & "\ClaudeTrafficLight.ps1""", 0, False
