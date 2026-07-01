#!/bin/bash

APP_NAME="${1:-AI CLI}"
SOUNDS_DIR="${AI_NOTIFY_SOUNDS_DIR:-$HOME/.local/share/ai-notify/sounds}"
SOUND="$SOUNDS_DIR/ok.mp3"
FALLBACK_SOUND="/System/Library/Sounds/Glass.aiff"

safe_app_name="$(printf '%s' "$APP_NAME" | tr -cd '[:alnum:]_-')"
tty_name="$(tty 2>/dev/null | tr '/ ' '__')"
stamp_file="${TMPDIR:-/tmp}/ai-cli-start-notify-${safe_app_name:-ai}-${tty_name:-notty}.stamp"
now="$(date +%s)"

if [ -f "$stamp_file" ]; then
  last="$(cat "$stamp_file" 2>/dev/null || printf '0')"
  if [ "$((now - last))" -lt 2 ] 2>/dev/null; then
    exit 0
  fi
fi
printf '%s' "$now" > "$stamp_file" 2>/dev/null || true

osascript - "$APP_NAME" <<'APPLESCRIPT' >/dev/null 2>&1 &
on run argv
  display notification ((item 1 of argv) & " session started") with title "AI CLI"
end run
APPLESCRIPT

if [ -f "$SOUND" ]; then
  afplay "$SOUND" >/dev/null 2>&1 &
elif [ -f "$FALLBACK_SOUND" ]; then
  afplay "$FALLBACK_SOUND" >/dev/null 2>&1 &
fi

exit 0
