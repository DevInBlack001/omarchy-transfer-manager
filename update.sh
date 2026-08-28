#!/usr/bin/env bash
# Pulls the latest source (if this is a git checkout) and re-applies
# install.sh so generated files and the running daemon pick up the change.
#
# If this plugin was added via `omarchy plugin add`, `omarchy plugin update
# <id>` already fast-forwards this same checkout for you; run this script
# (or at least `systemctl --user restart filetransferd.service`) afterward
# so the daemon actually reloads the new code, since a running process
# doesn't pick up file changes on its own.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/installer-common.sh"

INSTALL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes|-y) INSTALL_ARGS+=(--yes) ;;
  esac
done

if [ -d "$REPO_DIR/.git" ]; then
  if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
    echo "update: $REPO_DIR has uncommitted changes, not pulling to avoid clobbering them." >&2
    echo "Commit or stash them, then re-run this, or update manually." >&2
    exit 1
  fi
  echo "Pulling latest changes into $REPO_DIR..."
  git -C "$REPO_DIR" pull --ff-only
else
  echo "note: $REPO_DIR is not a git checkout; update the source yourself, then re-run this." >&2
fi

echo "Re-applying install steps..."
"$REPO_DIR/install.sh"

systemctl --user restart filetransferd.service
echo "filetransferd restarted on the updated code."
