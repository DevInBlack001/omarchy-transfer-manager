#!/usr/bin/env python3
"""CLI for filetransferd. Also invoked as a subprocess by the Quickshell
plugin's Service.qml for both status polling and control actions, following
the same pattern other Omarchy panel plugins use for their helper scripts.
"""
import argparse
import json
import os
import socket
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ft_common as common


def connect(timeout):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect(common.socket_path())
        return sock
    except OSError:
        return None


def ensure_daemon():
    sock = connect(0.5)
    if sock:
        return sock
    subprocess.run(["systemctl", "--user", "start", "filetransferd.service"],
                    check=False, capture_output=True, timeout=5)
    deadline = time.monotonic() + 3.0
    while time.monotonic() < deadline:
        sock = connect(0.5)
        if sock:
            return sock
        time.sleep(0.15)
    return None


def request(cmd, args=None, start_if_needed=True):
    sock = ensure_daemon() if start_if_needed else connect(0.5)
    if not sock:
        return {"ok": False, "error": "filetransferd is not running"}
    try:
        sock.sendall((json.dumps({"cmd": cmd, "args": args or {}}, separators=(",", ":")) + "\n").encode("utf-8"))
        sock.settimeout(10.0)
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = sock.recv(65536)
            if not chunk:
                break
            buf += chunk
            if len(buf) > common.MAX_LINE_BYTES:
                return {"ok": False, "error": "response too large"}
        if not buf:
            return {"ok": False, "error": "no response from daemon"}
        return json.loads(buf.decode("utf-8"))
    except (OSError, ValueError) as exc:
        return {"ok": False, "error": str(exc)}
    finally:
        sock.close()


def cmd_list(_args):
    result = request("list")
    result.setdefault("jobs", [])
    print(json.dumps(result, separators=(",", ":")))
    return 0


def cmd_ping(_args):
    result = request("ping", start_if_needed=False)
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result.get("ok") else 1


def cmd_clear(_args):
    return _print_error_and_exit(request("clear_finished"), "clear failed")


def cmd_enqueue(args):
    result = request("enqueue", {"mode": args.mode, "sources": args.sources, "dest": args.dest})
    if not result.get("ok"):
        print(result.get("error", "enqueue failed"), file=sys.stderr)
        return 1
    print(json.dumps(result, separators=(",", ":")))
    return 0


def cmd_reorder(args):
    return _print_error_and_exit(request("reorder", {"id": args.id, "position": args.position}), "reorder failed")


def _simple_action(name):
    def handler(args):
        return _print_error_and_exit(request(name, {"id": args.id}), name + " failed")
    return handler


def _print_error_and_exit(result, default_error):
    if not result.get("ok"):
        print(result.get("error", default_error), file=sys.stderr)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(prog="ftctl")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list")
    sub.add_parser("ping")
    sub.add_parser("clear")

    p_enq = sub.add_parser("enqueue")
    p_enq.add_argument("--move", dest="mode", action="store_const", const="move")
    p_enq.add_argument("--copy", dest="mode", action="store_const", const="copy")
    p_enq.set_defaults(mode="copy")
    p_enq.add_argument("dest")
    p_enq.add_argument("sources", nargs="+")

    for name in ("pause", "resume", "cancel"):
        p = sub.add_parser(name)
        p.add_argument("id")

    p_reorder = sub.add_parser("reorder")
    p_reorder.add_argument("id")
    p_reorder.add_argument("position", type=int)

    args = parser.parse_args()
    handlers = {
        "list": cmd_list, "ping": cmd_ping, "clear": cmd_clear, "enqueue": cmd_enqueue,
        "pause": _simple_action("pause"), "resume": _simple_action("resume"),
        "cancel": _simple_action("cancel"), "reorder": cmd_reorder,
    }
    sys.exit(handlers[args.command](args))


if __name__ == "__main__":
    main()
