# Claude Traffic Light

A small Windows status light for Claude Code.

It shows:

- Green: Claude is running
- Yellow: Claude needs manual action or permission
- Blue: Claude is done or idle

The window is a small iOS-style WPF floating card. It stays on top, can be dragged, and reads status from `D:\ClaudeTrafficLight\state.txt`.

## Files

- `ClaudeTrafficLight.ps1`: WPF floating status window
- `Start-ClaudeWithLight.ps1`: wrapper that starts Claude in `D:\Claude Code`
- `claude.cmd`: cmd entry point
- `StartClaudeLight.vbs`: hidden launcher for the light window
- `Stop-ClaudeLights.ps1`: stops existing light windows
- `hooks/Set-ClaudeLightState.ps1`: Claude Code hook state writer
- `hooks/ClaudePermissionHook.ps1`: permission hook with safe auto-approval and dangerous-command fallback

## Install

Copy this folder to:

```powershell
D:\ClaudeTrafficLight
```

Add `D:\ClaudeTrafficLight` to your user `PATH`, then make sure `claude` points to `D:\ClaudeTrafficLight\claude.cmd`.

Add the hooks from `claude-settings-hooks.example.json` into your Claude Code settings:

```powershell
C:\Users\<you>\.claude\settings.json
```

Do not commit your real Claude settings if they contain tokens.

## Notes

The wrapper starts Claude inside:

```powershell
D:\Claude Code
```

Dangerous operations such as recursive deletion, process killing, disk formatting, registry deletion, and hard git resets are not auto-approved.
