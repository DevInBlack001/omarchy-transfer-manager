# Transfer Manager

A file transfer queue that keeps running, and stays controllable, even if
the file manager that started it crashes.

## Why

A GTK file manager's built-in copy/move runs as threads inside its own
process. If Thunar, Nautilus, or whatever else segfaults mid-transfer, the
transfer dies with it, and there was never anything to pause, resume, or
cancel from the outside anyway.

This project moves the actual work into a small standalone daemon,
`filetransferd`, supervised by systemd `--user` and independent of any file
manager or desktop shell. A Quickshell panel (built for
[Omarchy](https://omarchy.org)) gives you a bar icon and a popup to monitor
and control the queue, but the daemon itself doesn't need it running to keep
transferring files.

## What's here

| Piece | Purpose |
|---|---|
| `manifest.json`, `Panel.qml`, `Service.qml`, `Model.js`, `TransferIcon.qml` | The Omarchy Quickshell plugin: bar icon + popup panel, polls `ftctl` for status. Lives at the repo root because that's where Omarchy's plugin loader expects a manifest. |
| `daemon/filetransferd.py` | Runs queued copy/move jobs with `rsync`, one process tree per job, independent of any caller. |
| `daemon/ftctl.py` | CLI/client for the daemon: enqueue, list, pause, resume, cancel, reorder, clear. |
| `systemd/filetransferd.service.in` | Template systemd `--user` unit (auto-restarts the daemon on failure). |
| `integration/send-to-transfer-manager.sh` | Hands a file-manager selection to the daemon instead of letting the file manager copy it itself. |
| `install.sh` / `update.sh` / `uninstall.sh` | Set up, refresh, and remove the daemon-side pieces (see below). |

## The bar icon

The icon is always shown, whether or not anything is transferring: dimmed
when idle, full brightness with a live percentage badge while something is
running. Hovering it shows a tooltip ("No ongoing transfer" when idle, or
how many transfers are active); clicking it opens the queue, which says
"Nothing queued" when there's nothing to show.

## How the queue behaves

- One transfer runs at a time by default (`FILETRANSFERD_MAX_CONCURRENT`,
  1–4).
- **Pause** freezes that job (`SIGSTOP` on its `rsync` process) and
  immediately frees the slot, so the next queued job starts right away.
- **Resume** puts a paused job back in front of the queue. If a slot is
  free it picks up instantly (`SIGCONT` on the same process, from the exact
  byte it stopped at); if not, it waits for one, without losing progress.
- **Cancel** stops the job for good. rsync's `--partial` and
  `--partial-dir` mean anything already copied is kept on disk rather than
  silently deleted, in case you want it.
- The queue is persisted to disk and reloaded if the daemon restarts
  (crash, `systemctl restart`, reboot); anything that was mid-transfer just
  resumes where it left off.

## Requirements

- `python3`, `rsync`
- `systemd --user`
- [Quickshell](https://quickshell.org) via an Omarchy install, for the
  panel (the daemon and CLI work fine without it)
- `zenity` and `notify-send`, for the file-manager "send to" scripts

## Install from the Omarchy plugin marketplace

```
omarchy plugin add https://github.com/DevInBlack001/omarchy-transfer-manager.git --enable
```

This clones the repo straight into `~/.config/omarchy/plugins/filetransfer`
and registers the bar widget — it's the Quickshell panel's normal install
path. It does **not** set up the daemon, `ftctl`, or the file-manager
integration on its own (those aren't things the plugin loader knows how to
run), so also run the bundled installer once, from wherever it landed:

```
~/.config/omarchy/plugins/filetransfer/install.sh
```

Until that's run, the panel will show "Daemon unreachable" — it has nothing
to talk to yet.

**Updating** a marketplace install:

```
omarchy plugin update filetransfer
```

This fast-forwards the panel's code, but a running daemon doesn't reload
its own source file on disk by itself, so also run:

```
~/.config/omarchy/plugins/filetransfer/update.sh --yes
```

(`update.sh` re-runs the installer and restarts `filetransferd` for you;
`--yes` skips the confirmation prompts it would otherwise need for a fresh
conflict, safe here since you already own everything it's about to touch.)

**Removing** a marketplace install:

```
~/.config/omarchy/plugins/filetransfer/uninstall.sh
omarchy plugin remove filetransfer
```

Run the uninstaller first (it stops the daemon and removes `ftctl`, the
systemd unit, and the Nautilus scripts) — `omarchy plugin remove` only
knows about the plugin folder itself, not the daemon-side pieces alongside
it.

## Install from a manual git clone

```sh
git clone https://github.com/DevInBlack001/omarchy-transfer-manager.git
cd omarchy-transfer-manager
./install.sh
```

Then enable the panel from Omarchy's bar-widget picker, or:

```
omarchy plugin enable filetransfer
```

`install.sh` is safe to re-run (e.g. after `git pull`, or if you move the
repo) — that's what `update.sh` uses it for. **It never overwrites a file
it didn't create itself**: every file it writes (`~/.local/bin/ftctl`,
`~/.config/systemd/user/filetransferd.service`, the Nautilus scripts, the
`~/.config/omarchy/plugins/filetransfer` link) is tagged with a marker
comment, and if something else is already at that path, it asks before
replacing it — or skips it automatically, unwritten, if run
non-interactively. It never touches `~/.config/omarchy/shell.json` or any
other Omarchy configuration; enabling the bar widget is a separate step you
do yourself.

```sh
./update.sh       # git pull (if clean), re-run install.sh, restart the daemon
./uninstall.sh    # stop the daemon, remove only what install.sh created
```

Both accept `--yes`/`-y` to skip confirmation prompts for scripted use; by
default (and always when not run from a real terminal) they ask before
touching or removing anything, and default to declining rather than acting.

## Using it

Command line:

```sh
ftctl enqueue --copy /path/to/destination /path/to/file [more files...]
ftctl enqueue --move /path/to/destination /path/to/folder
ftctl list                 # JSON: every job, running/queued/paused/history
ftctl pause <job-id>
ftctl resume <job-id>
ftctl cancel <job-id>
ftctl reorder <job-id> <position>
ftctl clear                # drop finished/errored/cancelled jobs from history
```

From a file manager: in Nautilus, right-click a selection → **Scripts** →
**Copy to Transfer Manager** or **Move to Transfer Manager**; you'll be
prompted for a destination folder. For Thunar, add a Custom Action that
runs `integration/send-to-transfer-manager.sh copy %F` (and a second one
with `move` in place of `copy`).

From Quickshell: the bar icon is always there; click it to open the queue,
with pause/resume/cancel per job.

## License

MIT, see [LICENSE](LICENSE).
