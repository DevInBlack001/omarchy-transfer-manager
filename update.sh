#!/usr/bin/env bash
# Re-applies install.sh against whatever is currently checked out here, and
# restarts the daemon so it picks up any code change.
#
# Deliberately does NOT fetch new source itself. Fetching and applying are
# kept as two separate, explicit steps: for a marketplace install, run
# `omarchy plugin update filetransfer` first (that's what advances this
# checkout); for a manual clone, run `git pull` yourself first. Either way,
# by the time this script runs, whatever is on disk is exactly what you
# already chose to have here, not something this script went and fetched
# on its own right before executing it.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/installer-common.sh"

INSTALL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes|-y) INSTALL_ARGS+=(--yes) ;;
  esac
done

if [ -d "$REPO_DIR/.git" ]; then
  echo "Applying install steps for $(git -C "$REPO_DIR" rev-parse --short HEAD) at $REPO_DIR..."
else
  echo "Applying install steps for $REPO_DIR..."
fi

"$REPO_DIR/install.sh" "${INSTALL_ARGS[@]}"

systemctl --user restart filetransferd.service
echo "filetransferd restarted on the current checkout."
