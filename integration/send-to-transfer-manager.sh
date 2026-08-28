#!/usr/bin/env bash
# Hands a file-manager selection off to filetransferd instead of letting the
# file manager copy/move it in its own process. Meant to be wired up as a
# Nautilus Script or a Thunar Custom Action.
#
# Usage: send-to-transfer-manager.sh <copy|move> [path...]
# With no explicit paths, falls back to Nautilus's selection env var.
set -euo pipefail

mode="${1:-copy}"
shift || true

paths=("$@")
if [ "${#paths[@]}" -eq 0 ] && [ -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && paths+=("$line")
  done <<< "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS"
fi

if [ "${#paths[@]}" -eq 0 ]; then
  command -v notify-send >/dev/null 2>&1 && notify-send "Transfer Manager" "No files selected"
  exit 1
fi

dest=$(zenity --file-selection --directory --title="Send to Transfer Manager ($mode)" 2>/dev/null) || exit 0

if output=$("$HOME/.local/bin/ftctl" enqueue "--$mode" "$dest" -- "${paths[@]}" 2>&1); then
  command -v notify-send >/dev/null 2>&1 && notify-send "Transfer Manager" "Queued ${#paths[@]} item(s) to $dest"
else
  command -v notify-send >/dev/null 2>&1 && notify-send "Transfer Manager" "Failed to queue: $output"
  exit 1
fi
