#!/bin/bash
EVENT="${1:-turn-ended}"
PAYLOAD="${2:-}"

COMPUTER_USE="$HOME/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
AUDIO_NOTIFY="$HOME/.local/bin/codex-notify.sh"

if [ -x "$COMPUTER_USE" ]; then
  "$COMPUTER_USE" "$EVENT" "$PAYLOAD" >/dev/null 2>&1 &
fi

if [ -x "$AUDIO_NOTIFY" ]; then
  "$AUDIO_NOTIFY" "codex" "$PAYLOAD" >/dev/null 2>&1 &
fi

exit 0
