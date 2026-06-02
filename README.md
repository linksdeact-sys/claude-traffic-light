# Claude Traffic Light

Windows 上给 Claude Code 用的小状态灯。

- 绿灯：Claude 正在跑
- 黄灯：Claude 等你确认权限或手动操作
- 蓝灯：Claude 已完成或空闲

窗口是一个 iOS 风格的小浮窗，会跟着 `claude` 一起启动，退出 Claude 后也会自动关闭。

## 一键安装

打开 PowerShell，粘贴这一行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main/install.ps1 | iex"
```

装完后重开 PowerShell，然后正常输入：

```powershell
claude
```

默认安装到：

```text
D:\ClaudeTrafficLight
```

默认让 Claude 在这里工作：

```text
D:\Claude Code
```

如果电脑没有 D 盘，安装脚本会自动改用用户目录。

## 它会做什么

安装脚本会自动完成：

- 找到你电脑上的 `claude.exe`
- 复制状态灯文件
- 添加 `D:\ClaudeTrafficLight` 到用户 PATH
- 写 PowerShell profile，让 `claude` 自动启动状态灯包装器
- 给 Claude Code 安装 hooks
- 备份原来的 `C:\Users\<you>\.claude\settings.json`
- 生成 `config.json`

它不会写入你的 API token，也不会上传你的 Claude 配置。

## 自检

如果装完不好用，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\doctor.ps1"
```

它会检查：

- 文件是否齐全
- Claude 是否找到
- PATH 是否写好
- PowerShell profile 是否写好
- hooks 是否写好
- 状态灯脚本语法是否正常

## 卸载

只取消 PATH、profile、hooks，保留文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\uninstall.ps1"
```

连安装目录一起删掉：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\uninstall.ps1" -RemoveFiles
```

## 自定义安装位置

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = irm https://raw.githubusercontent.com/linksdeact-sys/claude-traffic-light/main/install.ps1; & ([scriptblock]::Create($s)) -InstallDir 'E:\Tools\ClaudeTrafficLight' -Workspace 'E:\Claude Code'"
```

## 文件说明

- `install.ps1`：一键安装
- `uninstall.ps1`：卸载
- `doctor.ps1`：自检
- `ClaudeTrafficLight.ps1`：WPF 状态灯窗口
- `Start-ClaudeWithLight.ps1`：Claude 启动包装器
- `claude.cmd`：命令行入口
- `StartClaudeLight.vbs`：隐藏启动状态灯
- `Stop-ClaudeLights.ps1`：关闭状态灯
- `hooks/Set-ClaudeLightState.ps1`：Claude hooks 状态写入
- `hooks/ClaudePermissionHook.ps1`：权限 hook，安全操作自动放行，危险操作保留确认

## 权限逻辑

会自动放行常见安全操作，例如读文件、搜索、普通编辑、网页读取等。

这些危险操作不会自动放行：

- 递归删除
- 强制删除
- `git reset --hard`
- `git clean -fd`
- 进程强杀
- 注册表删除
- 磁盘格式化
- 系统目录/SSH 相关敏感路径

## 手动安装

不想用一键安装时，也可以手动复制整个仓库到：

```text
D:\ClaudeTrafficLight
```

然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\ClaudeTrafficLight\install.ps1"
```
