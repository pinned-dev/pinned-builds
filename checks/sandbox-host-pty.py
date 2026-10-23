#!/usr/bin/env python3
"""Check: the build sandbox cannot open the host's terminals (known failure:
exits 1 until the sandbox is fixed).

The host filesystem is read-only inside the sandbox, but a read-only mount
does not stop a device node from being opened for writing, and the mapped
root inside has the runner's kernel uid, which owns the runner's ptys. So
the build can open the host's /dev/pts/<n> and, through /dev/tty, the
terminal of the session that started it, and write to (or read from) them.

The check opens a pty pair on the host and starts the sandbox in a new
session with that pty as its controlling terminal, runs a probe through
sandbox.sh and requires that, inside, neither the host pty by its path nor
/dev/tty can be opened for writing.

Exit 0 when both hold, 1 when either fails, 2 when the check cannot run (no
ptys here, or the sandbox does not start).
Run it locally with `python3 -I checks/sandbox-host-pty.py`.
"""
import fcntl
import os
import pathlib
import subprocess
import sys
import termios

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
SANDBOX = ROOT / "scripts" / "sandbox.sh"


def can_write(path):
    try:
        fd = os.open(path, os.O_WRONLY | os.O_NOCTTY)
    except OSError:
        return False
    os.close(fd)
    return True


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--probe":
        print(f"host-pty={int(can_write(sys.argv[2]))} dev-tty={int(can_write('/dev/tty'))}")
        return 0
    try:
        master, slave = os.openpty()
        name = os.ttyname(slave)
    except OSError as e:
        print(f"no pty on this host ({e}); check not run", file=sys.stderr)
        return 2
    if not can_write(name):
        print(f"positive control: {name} is not writable on the host; check not run", file=sys.stderr)
        return 2

    def own_terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
    try:
        r = subprocess.run(
            [str(SANDBOX), "--", sys.executable, "-I", str(pathlib.Path(__file__).resolve()),
             "--probe", name],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            pass_fds=(slave,), preexec_fn=own_terminal, timeout=300, check=False)
    except (OSError, subprocess.SubprocessError) as e:
        print(f"cannot run the sandbox: {e}", file=sys.stderr)
        return 2
    finally:
        os.close(slave)
        os.close(master)
    if r.returncode != 0:
        print(f"the sandbox failed (exit {r.returncode}); check not run", file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        return 2
    line = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    inside = dict(kv.split("=", 1) for kv in line.split() if "=" in kv)
    if set(inside) != {"host-pty", "dev-tty"}:
        print(f"unexpected probe output: {line!r}", file=sys.stderr)
        return 2
    failures = []
    if inside["host-pty"] != "0":
        failures.append(f"the host pty {name} can be opened for writing inside the sandbox")
    if inside["dev-tty"] != "0":
        failures.append("the controlling terminal (/dev/tty) can be opened for writing inside the sandbox")
    for f in failures:
        print(f"FAIL: {f}")
    if not failures:
        print("sandbox-host-pty: host terminals cannot be opened")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
