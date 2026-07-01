#!/bin/bash
set -euo pipefail

CONFIG="$HOME/.codex/config.toml"
MUX="$HOME/.local/bin/codex-notify-mux.sh"
DESIRED="notify = [\"$MUX\", \"turn-ended\"]"

mkdir -p "$(dirname "$CONFIG")"
if [ ! -e "$CONFIG" ]; then
  : > "$CONFIG"
fi

if grep -Fxq "$DESIRED" "$CONFIG"; then
  exit 0
fi

TMP="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

if grep -Eq '^[[:space:]]*notify[[:space:]]*=' "$CONFIG"; then
  awk -v desired="$DESIRED" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*notify[[:space:]]*=/ {
      if (!replaced) {
        print desired
        replaced = 1
      }
      next
    }
    { print }
  ' "$CONFIG" > "$TMP"
else
  awk -v desired="$DESIRED" '
    BEGIN { inserted = 0 }
    !inserted && /^\[/ {
      print desired
      print ""
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print desired
      }
    }
  ' "$CONFIG" > "$TMP"
fi

if ! cmp -s "$TMP" "$CONFIG"; then
  cp "$CONFIG" "$CONFIG.bak.notify-guard-$(date +%Y%m%d-%H%M%S)"
  mv "$TMP" "$CONFIG"
  trap - EXIT
  echo "$(date '+%Y-%m-%d %H:%M:%S') restored Codex notify mux"
fi
