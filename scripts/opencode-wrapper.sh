#!/bin/bash
# OpenCode 包装脚本 - 带提示音支持
# Optional wrapper. Example alias: alias oc="$HOME/.local/bin/opencode-wrapper.sh"

OPENCODE_BIN="${OPENCODE_BIN:-/opt/homebrew/bin/opencode}"
NOTIFY_SCRIPT="$HOME/.local/bin/opencode-notify.sh"
START_NOTIFY_SCRIPT="$HOME/.local/bin/ai-cli-start-notify.sh"

should_start_notify() {
  [ -t 1 ] || return 1

  local arg
  for arg in "$@"; do
    case "$arg" in
      -h|--help|--version|version)
        return 1
        ;;
    esac
  done

  return 0
}

# 发送成功通知
send_success_notification() {
  local cwd="$PWD"
  local payload=$(cat <<EOF
{
  "source": "OpenCode",
  "last_assistant_message": "OpenCode session completed",
  "cwd": "$cwd",
  "hook_event_name": "Stop"
}
EOF
)
  echo "$payload" | "$NOTIFY_SCRIPT" "OpenCode" >/dev/null 2>&1
}

# 发送失败通知
send_failure_notification() {
  local exit_code="$1"
  local cwd="$PWD"
  local payload=$(cat <<EOF
{
  "source": "OpenCode",
  "last_assistant_message": "OpenCode exited with code $exit_code. Task may not have completed.",
  "cwd": "$cwd",
  "hook_event_name": "StopFailure"
}
EOF
)
  echo "$payload" | "$NOTIFY_SCRIPT" "OpenCode" >/dev/null 2>&1
}

# 发送启动通知
if should_start_notify "$@" && [ -x "$START_NOTIFY_SCRIPT" ]; then
  "$START_NOTIFY_SCRIPT" "OpenCode" >/dev/null 2>&1 &
fi

# 运行 OpenCode
"$OPENCODE_BIN" "$@"
EXIT_CODE=$?

# 根据退出代码发送通知
if [ -x "$NOTIFY_SCRIPT" ]; then
  if [ $EXIT_CODE -eq 0 ]; then
    send_success_notification
  else
    send_failure_notification $EXIT_CODE
  fi
fi

exit $EXIT_CODE
