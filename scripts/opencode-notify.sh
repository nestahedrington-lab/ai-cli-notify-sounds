#!/bin/bash
# OpenCode 本地通知脚本
# 直接播放音频和发送通知，不依赖 Docker 服务

SOUNDS_DIR="${AI_NOTIFY_SOUNDS_DIR:-$HOME/.local/share/ai-notify/sounds}"
OK_SOUND="$SOUNDS_DIR/ok.mp3"
ERROR_SOUND="$SOUNDS_DIR/error.mp3"
FALLBACK_OK="/System/Library/Sounds/Glass.aiff"
FALLBACK_ERROR="/System/Library/Sounds/Basso.aiff"

# 从 stdin 读取 payload 或使用参数
if [ -t 0 ]; then
  # 没有 stdin，使用默认值
  LAST_MESSAGE="${1:-Task completed}"
  SOURCE="${2:-OpenCode}"
  HOOK_EVENT="${3:-Stop}"
  CWD="$PWD"
else
  # 从 stdin 读取 JSON
  PARSED="$(
    python3 -c '
import json, re, sys, os

def has_positive_failure_count(text):
    patterns = [
        r"\b(?:FAILED_TOTAL|FAILED_COUNT|FAILURES)\s*[:=]\s*(\d+)\b",
        r"\b(?:tests?\s+)?failed\s*[:=]\s*(\d+)\b",
        r"失败(?:数|数量)?(?:是|为|:|：|=)\s*(\d+)",
        r"失败\s*(\d+)\s*个",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            try:
                if int(match.group(1)) > 0:
                    return True
            except ValueError:
                pass
    return False

def is_error_message(msg):
    if not msg:
        return False

    lower = msg.lower()
    meta_patterns = [
        r"误判", r"误触发", r"不应(?:该)?(?:提示|触发|播放)",
        r"应该(?:提示|播(?:放)?)\s*ok", r"不代表.*(?:失败|failed)",
        r"不是.*(?:失败|failed)", r"并非.*(?:失败|failed)",
    ]
    if any(re.search(pattern, lower, re.IGNORECASE) for pattern in meta_patterns):
        return False
    if has_positive_failure_count(msg):
        return True

    patterns = [
        r"\b(?:codex|claude|opencode|task|turn|request)\s+(?:failed|did not complete|was not completed)\b",
        r"\b(?:i|codex|claude|opencode)\s+(?:could not|couldnt|cannot|cant|was unable to|am unable to)\s+(?:complete|finish|handle|apply|make|update|edit|run|verify|test|build|install|deploy)\b",
        r"\b(?:i|codex|claude|opencode)\s+failed\s+to\s+(?:complete|finish|handle|apply|make|update|edit|run|verify|test|build|install|deploy)\b",
        r"\b(?:build|tests?|typecheck|lint|npm|pnpm|python|node|git|command|process|script)\s+failed\b",
        r"\bverification\s+failed\b",
        r"\b(?:http\s*)?(?:status|code|error|last\s+status)\s*[:=]?\s*(?:401|402|403|408|409|429|500|502|503|504)\b",
        r"\b(?:401|402|403|408|409|429|500|502|503|504)\b.*\b(?:error|failed|failure|unavailable|timeout|rate|quota|billing|balance|credit|requests?)\b",
        r"\b429\s+too\s+many\s+requests\b",
        r"\btoo\s+many\s+requests\b",
        r"\bservice\s+unavailable\b",
        r"\bbad\s+gateway\b",
        r"\bgateway\s+timeout\b",
        r"\binternal\s+server\s+error\b",
        r"\brate\s+limit(?:ed|s| exceeded)?\b",
        r"\bquota\s+(?:exceeded|limit|insufficient|reached)\b",
        r"\b(?:insufficient|not\s+enough|low|no)\s+(?:balance|credits?|funds|quota)\b",
        r"\b(?:billing|payment|subscription)\s+(?:required|issue|failed|past\s+due)\b",
        r"任务(?:执行)?失败",
        r"本次(?:任务|请求)?(?:未完成|没完成)",
        r"(?:无法|未能|没能)完成(?:本次)?(?:任务|请求|处理|操作)?",
        r"(?:测试|构建|安装|部署|校验|验证|命令|脚本|进程)(?:执行)?失败",
    ]
    return any(re.search(pattern, lower, re.IGNORECASE) for pattern in patterns)

try:
    p = json.load(sys.stdin)
    event = p.get("hook_event_name", "")
    source = p.get("source", "OpenCode")
    msg = p.get("last_assistant_message", "") or ""
    cwd = p.get("cwd", "") or ""
    notification_type = p.get("notification_type", "") or ""
    
    task = msg.split(chr(10))[0][:80] if msg else "Task completed"
    project = cwd.split("/")[-1] if cwd else ""
    label = f"{project} | {task}" if project else task

    is_err = False
    needs_action = False

    if event == "Notification":
        needs_action = notification_type in {"permission_prompt", "elicitation_dialog"}
        if needs_action:
            action_text = p.get("message", "") or p.get("title", "") or "Needs attention"
            label = f"{project} | {action_text[:80]}" if project else action_text[:80]
    elif event == "StopFailure":
        is_err = True
    elif event == "Stop":
        is_err = is_error_message(msg)
    elif not event and msg:
        is_err = is_error_message(msg)

    print(label)
    print(source)
    print(1 if is_err else 0)
    print(1 if needs_action else 0)
except Exception:
    print("Task completed")
    print("OpenCode")
    print(0)
    print(0)
' 2>/dev/null
  )"
  LAST_MESSAGE="$(printf '%s\n' "$PARSED" | sed -n '1p')"
  SOURCE="$(printf '%s\n' "$PARSED" | sed -n '2p')"
  IS_ERR="$(printf '%s\n' "$PARSED" | sed -n '3p')"
  NEEDS_ACTION="$(printf '%s\n' "$PARSED" | sed -n '4p')"
fi

# 确定通知类型和音频
if [ "$NEEDS_ACTION" = "1" ]; then
  TITLE="$SOURCE 🔔"
  SUBTITLE="Needs Action"
  SOUND="$ERROR_SOUND"
  FALLBACK="$FALLBACK_ERROR"
elif [ "$IS_ERR" = "1" ]; then
  TITLE="$SOURCE ❌"
  SUBTITLE="Task Failed"
  SOUND="$ERROR_SOUND"
  FALLBACK="$FALLBACK_ERROR"
else
  TITLE="$SOURCE ✅"
  SUBTITLE="Task Complete"
  SOUND="$OK_SOUND"
  FALLBACK="$FALLBACK_OK"
fi

# 发送通知
MESSAGE="${LAST_MESSAGE:-Task completed}"
osascript - "$MESSAGE" "$TITLE" "$SUBTITLE" <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)
end run
APPLESCRIPT

# 播放音频
if [ -f "$SOUND" ]; then
  afplay "$SOUND" &
elif [ -f "$FALLBACK" ]; then
  afplay "$FALLBACK" &
fi

exit 0
