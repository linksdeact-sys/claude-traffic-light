# Claude Traffic Light

一个给 **Claude Code CLI** 用的 Windows 状态灯。

它会在你运行 `claude` 时自动出现，用一个简洁的小浮窗告诉你 Claude 当前在干什么。支持同时打开多个 Claude Code，每个会话都会显示成单独一行。

> 非官方项目，只是一个本地小工具。

## 效果

状态灯会显示在屏幕右上角附近：

- 绿点：Claude 正在运行
- 黄点：Claude 正在等你确认权限或手动操作
- 蓝点：Claude 已完成或空闲

多开时会变成一个小型会话面板：

- 每个 Claude Code 会话一行
- 每一行显示自己的状态
- 点击某一行，会尝试把对应终端窗口拉到最前面
- 关闭某个 Claude，只移除它自己的那一行
- 所有 Claude 都退出后，状态灯才自动关闭

## 一键安装

打开 PowerShell，复制粘贴这一行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main/install.ps1 | iex"
```

安装完成后，重新打开 PowerShell，然后正常运行：

```powershell
claude
```

默认安装位置：

```text
D:\ClaudeTrafficLight
```

默认 Claude 工作目录：

```text
D:\Claude Code
```

如果电脑没有 D 盘，安装脚本会自动改用用户目录。

## 安装脚本会做什么

`install.ps1` 会自动完成这些事：

- 查找你电脑上的 `claude.exe`
- 复制状态灯脚本到安装目录
- 把安装目录加入用户 PATH
- 修改 PowerShell profile，让 `claude` 自动走状态灯包装器
- 给 Claude Code 安装 hooks
- 备份原来的 `C:\Users\<you>\.claude\settings.json`
- 生成本地 `config.json`

它不会写入、打印、上传你的 API token。

## 使用

安装后照常用 Claude Code：

```powershell
claude
```

或者：

```powershell
claude -p "只回复 OK"
```

状态灯会自动跟随启动和退出。多开多个 PowerShell / Windows Terminal 标签页时，每个 Claude 会话会在同一个状态灯里显示成一行。

## 自检

如果装完后不好用，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\doctor.ps1"
```

它会检查：

- 文件是否齐全
- Claude Code 是否能找到
- PATH 是否写好
- PowerShell profile 是否写好
- hooks 是否写好
- 状态灯脚本语法是否正常

如果输出里出现 `BAD`，把 doctor 输出贴到 issue 里会比较容易排查。

## 更新

重新运行一键安装命令即可覆盖更新：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main/install.ps1 | iex"
```

安装脚本会重新复制最新文件，并保留你的本地配置。

## 卸载

只移除 PATH、profile 和 hooks，保留安装目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\uninstall.ps1"
```

连安装目录一起删除：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\uninstall.ps1" -RemoveFiles
```

## 自定义安装位置

如果你想安装到别的目录，可以这样运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = irm https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main/install.ps1; & ([scriptblock]::Create($s)) -InstallDir 'E:\Tools\ClaudeTrafficLight' -Workspace 'E:\Claude Code'"
```

## 文件说明

- `install.ps1`：一键安装脚本
- `uninstall.ps1`：卸载脚本
- `doctor.ps1`：自检脚本
- `ClaudeTrafficLight.ps1`：WPF 状态灯界面
- `Start-ClaudeWithLight.ps1`：Claude Code 启动包装器
- `claude.cmd`：命令行入口
- `StartClaudeLight.vbs`：隐藏启动状态灯窗口
- `Stop-ClaudeLights.ps1`：关闭状态灯窗口
- `hooks/Set-ClaudeLightState.ps1`：Claude hooks 状态写入脚本
- `hooks/ClaudePermissionHook.ps1`：权限 hook，安全操作自动放行，危险操作保留确认

运行时会生成这些文件或目录：

- `instances/`：每个 Claude 会话一份状态文件
- `logs/`：每个 Claude 会话一份 debug log
- `last-hook-event.jsonl`：hook 事件日志
- `config.json`：本机安装配置

这些运行时文件已加入 `.gitignore`。

## 权限逻辑

状态灯内置了一个简单的权限 hook。常见安全操作会自动放行，例如：

- 读取文件
- 列目录
- 搜索
- 普通编辑
- 网页读取

这些危险操作不会自动放行：

- 递归删除
- 强制删除
- `git reset --hard`
- `git clean -fd`
- 进程强杀
- 注册表删除
- 磁盘格式化
- 系统目录相关操作
- SSH 相关敏感路径操作

## 隐私和安全

这个工具只在本机运行。

它会读取和修改本机 Claude Code 的 hooks 配置，但不会上传你的 Claude 配置，也不会读取或上传你的 API token。

安装时会备份原来的 Claude settings：

```text
C:\Users\<you>\.claude\settings.json.bak-时间戳
```

## 手动安装

不想用一键安装时，可以把整个仓库复制到：

```text
D:\ClaudeTrafficLight
```

然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\install.ps1"
```
