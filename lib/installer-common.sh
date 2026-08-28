# Shared paths and helpers for install.sh, update.sh, uninstall.sh.
# Sourced, not executed directly: no shebang, no set -e of its own (the
# caller already set that), no hardcoded paths or usernames -- everything
# here is derived from this file's own location and the environment.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_BIN="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
NAUTILUS_SCRIPTS_DIR="$HOME/.local/share/nautilus/scripts"
MARKER="managed-by:file-transfer-plugin"

PLUGIN_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$REPO_DIR/manifest.json")"
# Same shape Omarchy's own plugin validator enforces (omarchy-plugin-validate):
# this id becomes a path component below, so a manifest that somehow ended up
# with "../" or similar in its id must not be trusted to build one.
case "$PLUGIN_ID" in
  ''|*/*|*..*) echo "installer-common: manifest.json has an unsafe plugin id: '$PLUGIN_ID'" >&2; exit 1 ;;
esac
PLUGIN_LINK="$PLUGINS_DIR/$PLUGIN_ID"
SERVICE_UNIT="$SYSTEMD_USER_DIR/filetransferd.service"
FTCTL_BIN="$LOCAL_BIN/ftctl"

# True if $1 exists and carries our marker, i.e. this installer wrote it.
ours() {
  [ -e "$1" ] && grep -qF "$MARKER" "$1" 2>/dev/null
}

# Prompts "$1 [y/N]"; true only on an explicit yes. A non-interactive shell
# (no tty) or an EOF on read both default to no -- never destroy or
# overwrite something without someone actually answering yes. Set
# ASSUME_YES=1 (each script's --yes/-y flag) to answer yes to everything,
# for scripted/CI use -- an explicit opt-in, not a change to the default.
confirm() {
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "skip: non-interactive, assuming no for: $1" >&2
    return 1
  fi
  local reply=""
  read -r -p "$1 [y/N] " reply || reply="n"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Returns 0 if it's fine to write $1: nothing is there yet, or the file
# that's there is one of ours (safe to refresh in place). Otherwise asks.
ok_to_write() {
  local target="$1"
  [ ! -e "$target" ] && return 0
  ours "$target" && return 0
  confirm "$target already exists and wasn't created by this installer. Overwrite it?"
}
