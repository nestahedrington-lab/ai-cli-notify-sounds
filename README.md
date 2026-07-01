# AI CLI Notify Sounds

为 macOS 和 Windows 上的 Codex、Claude Code、OpenCode 增加任务完成、需要人工确认时的系统通知和提示音。

实现方式很简单：三个 CLI 在任务结束或需要你操作时触发本地脚本；macOS 用 `osascript` 发通知、`afplay` 播放提示音，Windows 用 PowerShell 发系统托盘通知并播放提示音。

## 支持范围

- macOS
- Windows
- Codex notify hook
- Claude Code hooks
- OpenCode plugin

## 安装

### macOS：从 GitHub 安装

```bash
tmpdir="$(mktemp -d)"
curl -L "https://github.com/nestahedrington-lab/ai-cli-notify-sounds/archive/refs/heads/main.tar.gz" \
  | tar -xz -C "$tmpdir" --strip-components=1
bash "$tmpdir/install.sh"
```

### macOS：从本地源码安装

克隆或下载仓库后运行：

```bash
bash install.sh
```

### Windows：从 GitHub 安装

在 PowerShell 里运行：

```powershell
$tmp = Join-Path $env:TEMP ("ai-notify-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Invoke-WebRequest "https://github.com/nestahedrington-lab/ai-cli-notify-sounds/archive/refs/heads/main.zip" -OutFile "$tmp\source.zip"
Expand-Archive "$tmp\source.zip" -DestinationPath $tmp
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
powershell -ExecutionPolicy Bypass -File "$($src.FullName)\install.ps1"
```

### Windows：从本地源码安装

克隆或下载仓库后，在 PowerShell 里运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装脚本会：

- 在 macOS 上把通知脚本安装到 `~/.local/bin`
- 在 Windows 上把通知脚本安装到 `%LOCALAPPDATA%\ai-notify\bin`
- 安装声音文件和 OpenCode 插件
- 合并修改：
  - `~/.codex/config.toml`
  - `~/.claude/settings.json`
  - `~/.config/opencode/opencode.json`
- 修改前自动生成 `.bak.ai-notify-时间戳` 备份

安装后重启 Codex、Claude Code、OpenCode。

查看安装器帮助：

```bash
bash install.sh --help
```

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Help
```

## 手动验证

macOS 安装后可以运行：

```bash
~/.local/bin/opencode-notify.sh "OpenCode"
```

也可以直接测试音频：

```bash
afplay ~/.local/share/ai-notify/sounds/ok.mp3
afplay ~/.local/share/ai-notify/sounds/error.mp3
```

Windows 安装后可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ai-notify\bin\opencode-notify.ps1" "OpenCode"
```

## 配置检查

检查 `~/.codex/config.toml` 是否有：

```toml
notify = ["~/.local/bin/codex-notify-mux.sh", "turn-ended"]
```

实际文件里需要用绝对路径，例如 `/Users/你的用户名/.local/bin/codex-notify-mux.sh`。

检查 `~/.claude/settings.json` 的 `hooks` 是否包含 `Stop`、`Notification`，并且都调用：

```text
~/.local/bin/claude-notify.sh
```

检查 `~/.config/opencode/opencode.json` 的 `plugin` 数组是否包含：

```text
~/.config/opencode/plugins/opencode-notify.mjs
```

检查 `~/.local/share/ai-notify/sounds/ok.mp3` 和 `error.mp3` 是否存在。

Windows 对应检查：

- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.claude\settings.json`
- `%USERPROFILE%\.config\opencode\opencode.json`
- `%LOCALAPPDATA%\ai-notify\sounds\ok.mp3`
- `%LOCALAPPDATA%\ai-notify\sounds\error.mp3`

## 卸载

目前没有自动卸载脚本。可以手动删除安装文件，并从对应配置里移除 hook/plugin：

macOS：

```bash
rm -f ~/.local/bin/codex-notify-mux.sh
rm -f ~/.local/bin/codex-notify.sh
rm -f ~/.local/bin/claude-notify.sh
rm -f ~/.local/bin/opencode-notify.sh
rm -f ~/.local/bin/ai-cli-start-notify.sh
rm -f ~/.local/bin/ensure-codex-notify.sh
rm -f ~/.local/bin/opencode-wrapper.sh
rm -rf ~/.local/share/ai-notify
rm -f ~/.config/opencode/plugins/opencode-notify.mjs
```

Windows：

```powershell
Remove-Item -Force "$env:LOCALAPPDATA\ai-notify\bin\codex-notify.ps1" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:LOCALAPPDATA\ai-notify\bin\claude-notify.ps1" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:LOCALAPPDATA\ai-notify\bin\opencode-notify.ps1" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:LOCALAPPDATA\ai-notify\bin\notify-common.ps1" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\ai-notify\sounds" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:USERPROFILE\.config\opencode\plugins\opencode-notify.mjs" -ErrorAction SilentlyContinue
```

## 包内文件

- `scripts/codex-notify-mux.sh`：Codex notify 入口
- `scripts/codex-notify.sh`：Codex 通知和播放声音
- `scripts/claude-notify.sh`：Claude Code hook 通知和播放声音
- `scripts/opencode-notify.sh`：OpenCode 通知和播放声音
- `scripts/*.ps1`：Windows PowerShell 通知和播放声音
- `opencode/opencode-notify.mjs`：OpenCode 插件
- `sounds/ok.mp3`：成功提示音
- `sounds/error.mp3`：需要操作提示音
- `config-snippets/`：手动配置参考片段

## 开源协议

MIT

GitHub 发布步骤见 [GITHUB_PUBLISHING.md](GITHUB_PUBLISHING.md)。
