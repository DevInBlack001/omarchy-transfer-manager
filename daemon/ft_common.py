"""Shared constants and helpers for filetransferd and ftctl.

The daemon and CLI are separate processes talking over a Unix socket that
lives under XDG_RUNTIME_DIR, so only the invoking user's session can reach
it. Keeping the path/limit logic here means both sides agree on it exactly.
"""
import os
import socket
import struct

SOCK_NAME = "ctl.sock"
MAX_LINE_BYTES = 2 * 1024 * 1024
MAX_SOURCES = 10000
MAX_QUEUED_JOBS = 500
# Bounds the persisted queue.json read at startup. Generous relative to
# realistic use (a handful of sources per job, well under MAX_QUEUED_JOBS
# jobs at once) so it never rejects a legitimate queue, but still refuses
# to hand json.load() an unbounded file if queue.json were ever corrupted,
# replaced, or otherwise not what this daemon wrote.
MAX_QUEUE_STATE_BYTES = 64 * 1024 * 1024


def runtime_dir():
    base = os.environ.get("XDG_RUNTIME_DIR")
    if not base:
        raise RuntimeError("XDG_RUNTIME_DIR is not set; refusing to fall back to a shared /tmp path")
    d = os.path.join(base, "filetransferd")
    os.makedirs(d, mode=0o700, exist_ok=True)
    os.chmod(d, 0o700)
    return d


def socket_path():
    return os.path.join(runtime_dir(), SOCK_NAME)


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    d = os.path.join(base, "filetransferd")
    os.makedirs(d, mode=0o700, exist_ok=True)
    os.chmod(d, 0o700)
    return d


def queue_file():
    return os.path.join(state_dir(), "queue.json")


def log_file():
    return os.path.join(state_dir(), "daemon.log")


def peer_uid(sock):
    """UID of the process on the other end of a connected Unix socket, or None."""
    try:
        creds = sock.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
    except OSError:
        return None
    _pid, uid, _gid = struct.unpack("3i", creds)
    return uid
