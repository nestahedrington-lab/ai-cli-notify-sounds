#!/bin/bash
PAYLOAD="${2:-}"
if [ -z "$PAYLOAD" ]; then exit 0; fi

SOUNDS_DIR="${AI_NOTIFY_SOUNDS_DIR:-$HOME/.local/share/ai-notify/sounds}"

PARSED="$(
printf '%s' "$PAYLOAD" | python3 -c '
import json, re, sys

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
        r"误判",
        r"误触发",
        r"不应(?:该)?(?:提示|触发|播放)",
        r"应该(?:提示|播(?:放)?)\s*ok",
        r"不代表.*(?:失败|failed)",
        r"不是.*(?:失败|failed)",
        r"并非.*(?:失败|failed)",
    ]
    if any(re.search(pattern, lower, re.IGNORECASE) for pattern in meta_patterns):
        return False
    if has_positive_failure_count(msg):
        return True

    patterns = [
        r"\b(?:codex|claude|task|turn|request)\s+(?:failed|did not complete|was not completed)\b",
        r"\b(?:i|codex|claude)\s+(?:could not|couldnt|cannot|cant|was unable to|am unable to)\s+(?:complete|finish|handle|apply|make|update|edit|run|verify|test|build|install|deploy)\b",
        r"\b(?:i|codex|claude)\s+failed\s+to\s+(?:complete|finish|handle|apply|make|update|edit|run|verify|test|build|install|deploy)\b",
        r"\b(?:build|tests?|typecheck|lint|npm|pnpm|python|node|git|command|process|script)\s+failed\b",
        r"\bverification\s+failed\b",
        r"\bexceeded\s+retry\s+limit\b",
        r"\blast\s+status\s*:\s*429\b",
        r"\b429\s+too\s+many\s+requests\b",
        r"\btoo\s+many\s+requests\b",
        r"\brate\s+limit(?:ed|s| exceeded)?\b",
        r"\b(?:conversation|dialog|request|task|turn|response)\s+(?:was\s+)?(?:interrupted|aborted|cancelled|canceled)\b",
        r"\b(?:interrupted|aborted|cancelled|canceled)\b",
        r"\btraceback \(most recent call last\):",
        r"\bsegmentation fault\b",
        r"\bsigsegv\b",
        r"\bout of memory\b",
        r"\bpermission denied\b",
        r"\bcontext\s+(?:window|length|limit).*(?:exceeded|too large)\b",
        r"任务(?:执行)?失败",
        r"本次(?:任务|请求)?(?:未完成|没完成)",
        r"(?:无法|未能|没能)完成(?:本次)?(?:任务|请求|处理|操作)?",
        r"(?:我|codex|claude)(?:无法|未能|没能)(?:完成|处理|修改|运行|验证|测试|构建|安装|部署)",
        r"(?:测试|构建|安装|部署|校验|验证|命令|脚本|进程)(?:执行)?失败",
        r"(?:对话|请求|任务|响应|进程)(?:被|已)?中断",
        r"(?:需要|等待)(?:你|用户|人工)?(?:确认|输入|操作)",
        r"请(?:你)?(?:确认|输入|操作)",
        r"(?:permission|confirmation|approval)\s+(?:prompt|required|needed)",
        r"权限不足|没有权限",
    ]
    return any(re.search(pattern, lower, re.IGNORECASE) for pattern in patterns)

try:
    p = json.load(sys.stdin)
    msg = p.get("last-assistant-message", "") or ""
    cwd = p.get("cwd", "") or ""
    task = msg.split(chr(10))[0][:80]
    project = cwd.split("/")[-1] if cwd else ""
    label = f"{project} | {task}" if project else task

    print(label)
    print(1 if is_error_message(msg) else 0)
except Exception:
    print("Codex completed")
    print(0)
' 2>/dev/null
)"
MSG="$(printf '%s\n' "$PARSED" | sed -n '1p')"
IS_ERR="$(printf '%s\n' "$PARSED" | sed -n '2p')"

if [ "$IS_ERR" = "1" ]; then
  TITLE="Codex ❌"
  SUBTITLE="Task Failed"
  SOUND="$SOUNDS_DIR/error.mp3"
  FALLBACK_SOUND="/System/Library/Sounds/Basso.aiff"
else
  TITLE="Codex ✅"
  SUBTITLE="Task Complete"
  SOUND="$SOUNDS_DIR/ok.mp3"
  FALLBACK_SOUND="/System/Library/Sounds/Glass.aiff"
fi

MESSAGE="${MSG:-Codex completed}"

osascript - "$MESSAGE" "$TITLE" "$SUBTITLE" <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)
end run
APPLESCRIPT
if [ -f "$SOUND" ]; then
  afplay "$SOUND" &
elif [ -f "$FALLBACK_SOUND" ]; then
  afplay "$FALLBACK_SOUND" &
fi
