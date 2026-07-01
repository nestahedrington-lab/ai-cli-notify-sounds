#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="0.2.1"
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SOUND_DIR="$HOME/.local/share/ai-notify/sounds"
OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"

CODEX_CONFIG="$HOME/.codex/config.toml"
CLAUDE_CONFIG="$HOME/.claude/settings.json"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"

usage() {
  cat <<EOF
AI CLI Notify installer $APP_VERSION

Usage:
  bash install.sh [--help] [--version]

Installs local notification scripts and sound files for:
  - Codex
  - Claude Code
  - OpenCode

The installer writes user-level files only and creates timestamped backups
before modifying existing CLI configuration files.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  -v|--version)
    echo "$APP_VERSION"
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Run: bash install.sh --help" >&2
    exit 2
    ;;
esac

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Missing package file: $file" >&2
    exit 1
  fi
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "$file.bak.ai-notify-$(date +%Y%m%d-%H%M%S)"
  fi
}

require_command install
require_command python3
require_command osascript
require_command afplay

require_file "$PACKAGE_DIR/scripts/codex-notify-mux.sh"
require_file "$PACKAGE_DIR/scripts/codex-notify.sh"
require_file "$PACKAGE_DIR/scripts/claude-notify.sh"
require_file "$PACKAGE_DIR/scripts/opencode-notify.sh"
require_file "$PACKAGE_DIR/scripts/ai-cli-start-notify.sh"
require_file "$PACKAGE_DIR/scripts/ensure-codex-notify.sh"
require_file "$PACKAGE_DIR/scripts/opencode-wrapper.sh"
require_file "$PACKAGE_DIR/sounds/ok.mp3"
require_file "$PACKAGE_DIR/sounds/error.mp3"
require_file "$PACKAGE_DIR/opencode/opencode-notify.mjs"

echo "Installing AI CLI notification sounds..."

mkdir -p "$BIN_DIR" "$SOUND_DIR" "$OPENCODE_PLUGIN_DIR"

install -m 0755 "$PACKAGE_DIR/scripts/codex-notify-mux.sh" "$BIN_DIR/codex-notify-mux.sh"
install -m 0755 "$PACKAGE_DIR/scripts/codex-notify.sh" "$BIN_DIR/codex-notify.sh"
install -m 0755 "$PACKAGE_DIR/scripts/claude-notify.sh" "$BIN_DIR/claude-notify.sh"
install -m 0755 "$PACKAGE_DIR/scripts/opencode-notify.sh" "$BIN_DIR/opencode-notify.sh"
install -m 0755 "$PACKAGE_DIR/scripts/ai-cli-start-notify.sh" "$BIN_DIR/ai-cli-start-notify.sh"
install -m 0755 "$PACKAGE_DIR/scripts/ensure-codex-notify.sh" "$BIN_DIR/ensure-codex-notify.sh"
install -m 0755 "$PACKAGE_DIR/scripts/opencode-wrapper.sh" "$BIN_DIR/opencode-wrapper.sh"

install -m 0644 "$PACKAGE_DIR/sounds/ok.mp3" "$SOUND_DIR/ok.mp3"
install -m 0644 "$PACKAGE_DIR/sounds/error.mp3" "$SOUND_DIR/error.mp3"
install -m 0644 "$PACKAGE_DIR/opencode/opencode-notify.mjs" "$OPENCODE_PLUGIN_DIR/opencode-notify.mjs"

echo "Patching Codex config..."
mkdir -p "$(dirname "$CODEX_CONFIG")"
backup_file "$CODEX_CONFIG"
python3 - "$CODEX_CONFIG" "$BIN_DIR/codex-notify-mux.sh" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
notify_script = sys.argv[2]
desired = f'notify = ["{notify_script}", "turn-ended"]'

text = path.read_text() if path.exists() else ""
lines = text.splitlines()
new_lines = []
replaced = False

for line in lines:
    if re.match(r"^\s*notify\s*=", line):
        if not replaced:
            new_lines.append(desired)
            replaced = True
        continue
    new_lines.append(line)

if not replaced:
    inserted = False
    output = []
    for line in new_lines:
        if not inserted and line.startswith("["):
            output.append(desired)
            output.append("")
            inserted = True
        output.append(line)
    if not inserted:
        if output and output[-1] != "":
            output.append("")
        output.append(desired)
    new_lines = output

path.write_text("\n".join(new_lines).rstrip() + "\n")
PY

echo "Patching Claude Code config..."
mkdir -p "$(dirname "$CLAUDE_CONFIG")"
backup_file "$CLAUDE_CONFIG"
python3 - "$CLAUDE_CONFIG" "$BIN_DIR/claude-notify.sh" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
notify_script = sys.argv[2]

if path.exists() and path.read_text().strip():
    data = json.loads(path.read_text())
else:
    data = {}

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = {}

events = ["StopFailure", "Stop", "Notification"]

def contains_command(entries):
    if not isinstance(entries, list):
        return False
    for entry in entries:
        for hook in (entry.get("hooks") or []):
            if hook.get("command") == notify_script:
                return True
    return False

for event in events:
    entries = hooks.get(event)
    if not isinstance(entries, list):
        entries = []
    if not contains_command(entries):
        entries.append({
            "hooks": [{
                "type": "command",
                "command": notify_script,
                "args": [],
                "async": True,
            }]
        })
    hooks[event] = entries

data["hooks"] = hooks
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY

echo "Patching OpenCode config..."
mkdir -p "$(dirname "$OPENCODE_CONFIG")"
backup_file "$OPENCODE_CONFIG"
python3 - "$OPENCODE_CONFIG" "$OPENCODE_PLUGIN_DIR/opencode-notify.mjs" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
plugin_path = sys.argv[2]

if path.exists() and path.read_text().strip():
    data = json.loads(path.read_text())
else:
    data = {"$schema": "https://opencode.ai/config.json"}

plugins = data.get("plugin")
if not isinstance(plugins, list):
    plugins = []

seen = set()
for item in plugins:
    if isinstance(item, list) and item:
        seen.add(item[0])
    elif isinstance(item, str):
        seen.add(item)

if plugin_path not in seen and f"file://{plugin_path}" not in seen:
    plugins.append(plugin_path)

data["plugin"] = plugins
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY

echo "Done."
echo "Restart Codex, Claude Code, and OpenCode for the notification hooks to take effect."
