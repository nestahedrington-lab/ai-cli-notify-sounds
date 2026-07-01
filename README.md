# AI CLI Notify Sounds

为 macOS 上的 Codex、Claude Code、OpenCode 增加任务完成、失败、需要操作时的系统通知和提示音。

实现方式很简单：三个 CLI 在任务结束、失败、需要你操作时触发本地脚本；脚本用 macOS 自带的 `osascript` 发系统通知，用 `afplay` 播放 `ok.mp3` 或 `error.mp3`。

## 支持范围

- macOS
- Codex notify hook
- Claude Code hooks
- OpenCode plugin

## 安装

### 从 GitHub 安装

```bash
tmpdir="$(mktemp -d)"
curl -L "https://github.com/nestahedrington-lab/ai-cli-notify-sounds/archive/refs/heads/main.tar.gz" \
  | tar -xz -C "$tmpdir" --strip-components=1
bash "$tmpdir/install.sh"
```

### 从本地源码安装

克隆或下载仓库后运行：

```bash
bash install.sh
```

安装脚本会：

- 把通知脚本安装到 `~/.local/bin`
- 把声音文件安装到 `~/.local/share/ai-notify/sounds`
- 把 OpenCode 插件安装到 `~/.config/opencode/plugins/opencode-notify.mjs`
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

## 手动验证

安装后可以运行：

```bash
~/.local/bin/opencode-notify.sh "OpenCode"
```

也可以直接测试音频：

```bash
afplay ~/.local/share/ai-notify/sounds/ok.mp3
afplay ~/.local/share/ai-notify/sounds/error.mp3
```

## 配置检查

检查 `~/.codex/config.toml` 是否有：

```toml
notify = ["~/.local/bin/codex-notify-mux.sh", "turn-ended"]
```

实际文件里需要用绝对路径，例如 `/Users/你的用户名/.local/bin/codex-notify-mux.sh`。

检查 `~/.claude/settings.json` 的 `hooks` 是否包含 `Stop`、`StopFailure`、`Notification`，并且都调用：

```text
~/.local/bin/claude-notify.sh
```

检查 `~/.config/opencode/opencode.json` 的 `plugin` 数组是否包含：

```text
~/.config/opencode/plugins/opencode-notify.mjs
```

检查 `~/.local/share/ai-notify/sounds/ok.mp3` 和 `error.mp3` 是否存在。

## 卸载

目前没有自动卸载脚本。可以手动删除安装文件，并从对应配置里移除 hook/plugin：

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

## 包内文件

- `scripts/codex-notify-mux.sh`：Codex notify 入口
- `scripts/codex-notify.sh`：Codex 通知和播放声音
- `scripts/claude-notify.sh`：Claude Code hook 通知和播放声音
- `scripts/opencode-notify.sh`：OpenCode 通知和播放声音
- `opencode/opencode-notify.mjs`：OpenCode 插件
- `sounds/ok.mp3`：成功提示音
- `sounds/error.mp3`：失败或需要操作提示音
- `config-snippets/`：手动配置参考片段

## 开源协议

MIT

GitHub 发布步骤见 [GITHUB_PUBLISHING.md](GITHUB_PUBLISHING.md)。
