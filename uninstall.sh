#!/usr/bin/env bash
# Reverses install.sh: stops the daemon and removes only what this
# installer created (marker-tagged files, and the plugin link/registration
# if it's actually a link to this repo). Anything it doesn't recognize as
# its own is left alone and reported instead of removed.
#
# Job history and logs under ~/.local/state/filetransferd/ are left in
# place -- delete that directory yourself if you want them gone too.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/installer-common.sh"

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
  esac
done

echo "This stops filetransferd and removes ftctl, its systemd unit, the"
echo "Nautilus scripts, and the plugin link -- only the ones this installer"
echo "created. Transfer history/logs under ~/.local/state/filetransferd/ stay."
confirm "Continue?" || { echo "Aborted."; exit 0; }

systemctl --user disable --now filetransferd.service 2>/dev/null || true

if ours "$SERVICE_UNIT"; then
  rm -f "$SERVICE_UNIT"
  systemctl --user daemon-reload
elif [ -e "$SERVICE_UNIT" ]; then
  echo "left in place (not ours): $SERVICE_UNIT" >&2
fi

if ours "$FTCTL_BIN"; then
  rm -f "$FTCTL_BIN"
elif [ -e "$FTCTL_BIN" ]; then
  echo "left in place (not ours): $FTCTL_BIN" >&2
fi

for mode in Copy Move; do
  script_path="$NAUTILUS_SCRIPTS_DIR/$mode to Transfer Manager"
  if ours "$script_path"; then
    rm -f "$script_path"
  elif [ -e "$script_path" ]; then
    echo "left in place (not ours): $script_path" >&2
  fi
done

if [ -L "$PLUGIN_LINK" ] && [ "$(readlink -f "$PLUGIN_LINK" 2>/dev/null)" = "$(readlink -f "$REPO_DIR")" ]; then
  rm -f "$PLUGIN_LINK"
  echo "Unlinked $PLUGIN_LINK"
elif [ "$(readlink -f "$PLUGIN_LINK" 2>/dev/null)" = "$(readlink -f "$REPO_DIR")" ]; then
  # This repo checkout IS $PLUGIN_LINK (installed via `omarchy plugin add`).
  # Deleting our own directory out from under this running script would be
  # a bad idea; hand off to the tool that owns that lifecycle instead.
  echo "note: $PLUGIN_LINK is this repo (installed via 'omarchy plugin add')."
  echo "Remove it with: omarchy plugin remove $PLUGIN_ID"
else
  echo "note: $PLUGIN_LINK does not point at this repo; leaving it alone."
fi

echo "Done. filetransferd stopped and disabled."
