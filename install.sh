#!/usr/bin/env bash
# Wires filetransferd + ftctl + the Quickshell plugin into this user account.
# Safe to re-run after moving the repo, pulling updates, or editing any of
# the pieces (see update.sh for that as a single step).
#
# Never silently overwrites something this installer didn't create itself:
# every file it writes carries a marker comment, and anything already at the
# target path without that marker is left alone unless you explicitly say
# to replace it (or the run is non-interactive, in which case it's skipped).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/installer-common.sh"

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required but was not found on PATH" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync is required but was not found on PATH" >&2; exit 1; }

mkdir -p "$LOCAL_BIN" "$SYSTEMD_USER_DIR" "$PLUGINS_DIR" "$NAUTILUS_SCRIPTS_DIR"

if ok_to_write "$FTCTL_BIN"; then
  cat > "$FTCTL_BIN" <<EOF
#!/usr/bin/env bash
# $MARKER
exec python3 "$REPO_DIR/daemon/ftctl.py" "\$@"
EOF
  chmod +x "$FTCTL_BIN"
fi

if ok_to_write "$SERVICE_UNIT"; then
  {
    echo "# $MARKER"
    sed "s#__EXEC_PATH__#$REPO_DIR/daemon/filetransferd.py#" "$REPO_DIR/systemd/filetransferd.service.in"
  } > "$SERVICE_UNIT"
  systemctl --user daemon-reload
fi
systemctl --user enable --now filetransferd.service

chmod +x "$REPO_DIR/integration/send-to-transfer-manager.sh"

# manifest.json lives at the repo root, so the plugin folder Omarchy expects
# under ~/.config/omarchy/plugins/<id> IS this repo. If `omarchy plugin add`
# already cloned it straight there, PLUGIN_LINK and REPO_DIR are the same
# real path and there's nothing to do; otherwise link this checkout in.
if [ "$(readlink -f "$PLUGIN_LINK" 2>/dev/null)" = "$(readlink -f "$REPO_DIR")" ]; then
  : # already in place, either as our own symlink or as the repo itself
elif [ -e "$PLUGIN_LINK" ] || [ -L "$PLUGIN_LINK" ]; then
  if confirm "$PLUGIN_LINK already exists. Replace it with a link to this plugin?"; then
    rm -rf "$PLUGIN_LINK"
    ln -s "$REPO_DIR" "$PLUGIN_LINK"
  else
    echo "skip: leaving $PLUGIN_LINK untouched" >&2
  fi
else
  ln -s "$REPO_DIR" "$PLUGIN_LINK"
fi

for mode in Copy Move; do
  script_path="$NAUTILUS_SCRIPTS_DIR/$mode to Transfer Manager"
  if ok_to_write "$script_path"; then
    cat > "$script_path" <<EOF
#!/usr/bin/env bash
# $MARKER
exec "$REPO_DIR/integration/send-to-transfer-manager.sh" ${mode,,}
EOF
    chmod +x "$script_path"
  fi
done

echo "ftctl: $FTCTL_BIN"
echo "daemon status: systemctl --user status filetransferd.service"
echo "quickshell plugin: $PLUGIN_LINK -- enable it with: omarchy plugin enable $PLUGIN_ID"
echo "Nautilus: right-click a selection -> Scripts -> Copy/Move to Transfer Manager"
echo "Thunar (once installed): add a Custom Action running '$REPO_DIR/integration/send-to-transfer-manager.sh copy %F' (and a second one with 'move' for Move)"
