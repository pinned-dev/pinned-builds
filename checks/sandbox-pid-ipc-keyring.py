#!/usr/bin/env python3
"""Check: the build sandbox has its own PID and IPC namespaces and session
keyring (was a known failure; fixed).

scripts/sandbox.sh used to give the build new user, network and mount
namespaces only: it shared the host's PID namespace and /proc, the host's IPC
namespace and /dev/shm, and the session keyring of the process that started
it. The mapped root inside has the same kernel uid as the runner, so the
build could see runner processes and signal them. sandbox.sh now also
unshares the PID namespace (with a fresh /proc) and the IPC namespace, hides
/dev/shm and /dev/mqueue, and joins a new session keyring.

The check starts a marker process on the host (its environment holds a
random value) and a file under /dev/shm, then runs a probe through
sandbox.sh and requires, inside:
  - /proc/self/ns/pid and /proc/self/ns/ipc differ from the host's;
  - the session keyring differs from the host's and is empty;
  - the marker process is not visible in /proc (matched by PID and start
    time), its environ cannot be read and it cannot be signalled;
  - the /dev/shm file is not visible.

Exit 0 when all hold, 1 when any fails, 2 when the check cannot run (the
sandbox does not start here, or no TMPDIR outside the directories the
sandbox hides). Run it locally with
`TMPDIR=<dir> python3 -I checks/sandbox-pid-ipc-keyring.py`.
"""
import ctypes
import os
import pathlib
import platform
import secrets
import subprocess
import sys

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
SANDBOX = ROOT / "scripts" / "sandbox.sh"
SYS_KEYCTL = {"x86_64": 250, "aarch64": 219}
KEYCTL_GET_KEYRING_ID = 0
KEYCTL_READ = 11
KEY_SPEC_SESSION_KEYRING = -3


def keyctl(*args):
    nr = SYS_KEYCTL.get(platform.machine())
    if nr is None:
        return None
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long
    return libc.syscall(ctypes.c_long(nr), *[ctypes.c_long(a) if isinstance(a, int) else a for a in args])


def session_keyring():
    """(serial, number of links) of the session keyring, or (None, None)."""
    r = keyctl(KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 0)
    if r is None or r < 0:
        return None, None
    n = keyctl(KEYCTL_READ, r, None, 0)
    return r, (n // 4 if n is not None and n >= 0 else None)


def starttime(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return f.read().rsplit(")", 1)[1].split()[19]
    except (OSError, IndexError):
        return None


def probe(pid, start, marker, shm):
    """Inside the sandbox: print one key=value line."""
    out = {
        "pid": os.readlink("/proc/self/ns/pid"),
        "ipc": os.readlink("/proc/self/ns/ipc"),
    }
    serial, links = session_keyring()
    out["keyring"] = serial
    out["keyring-links"] = links
    visible = starttime(pid) == start
    out["host-pid-visible"] = int(visible)
    environ = False
    try:
        with open(f"/proc/{pid}/environ", "rb") as f:
            environ = marker.encode() in f.read()
    except OSError:
        pass
    out["host-environ-readable"] = int(environ)
    signalled = False
    if visible:
        try:
            os.kill(int(pid), 0)
            signalled = True
        except OSError:
            pass
    out["host-pid-signalled"] = int(signalled)
    out["host-shm-visible"] = int(os.path.exists(shm))
    print(" ".join(f"{k}={v}" for k, v in out.items()))
    return 0


def scratch_ok():
    base = os.environ.get("TMPDIR", "")
    if not base or not os.path.isdir(base):
        return False
    base = os.path.realpath(base)
    home = os.path.realpath(os.environ.get("HOME", "/nonexistent"))
    return not any(base == h or base.startswith(h + "/")
                   for h in ("/run", "/var/run", "/tmp", "/var/tmp", home))


def main():
    if len(sys.argv) == 6 and sys.argv[1] == "--probe":
        return probe(*sys.argv[2:])
    if not scratch_ok():
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    marker = "pb-marker-" + secrets.token_hex(16)
    shm = f"/dev/shm/pb-check-{secrets.token_hex(8)}"
    env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
    host = subprocess.Popen([sys.executable, "-I", "-c", "import time; time.sleep(300)"],
                            env=dict(env, PB_CHECK_MARKER=marker))
    shm_made = False
    try:
        start = None
        for _ in range(50):
            start = starttime(host.pid)
            if start:
                break
        with open(f"/proc/{host.pid}/environ", "rb") as f:
            if start is None or marker.encode() not in f.read():
                print("positive control: the marker process environ is not readable on the host;"
                      " check not run", file=sys.stderr)
                return 2
        try:
            with open(shm, "x"):
                shm_made = True
        except OSError:
            pass
        outside_serial, _ = session_keyring()
        outside = {"pid": os.readlink("/proc/self/ns/pid"), "ipc": os.readlink("/proc/self/ns/ipc")}
        try:
            r = subprocess.run(
                [str(SANDBOX), "--", sys.executable, "-I", str(pathlib.Path(__file__).resolve()),
                 "--probe", str(host.pid), start, marker, shm],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                timeout=300, check=False)
        except (OSError, subprocess.TimeoutExpired) as e:
            print(f"cannot run the sandbox: {e}", file=sys.stderr)
            return 2
    finally:
        host.kill()
        host.wait()
        if shm_made:
            os.unlink(shm)
    if r.returncode != 0:
        print(f"the sandbox failed (exit {r.returncode}); check not run", file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        return 2
    line = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    inside = dict(kv.split("=", 1) for kv in line.split() if "=" in kv)
    failures = []
    for k in ("pid", "ipc"):
        if inside.get(k) == outside[k]:
            failures.append(f"the sandbox shares the host {k} namespace ({outside[k]})")
    if inside.get("keyring") in (None, "None"):
        failures.append("the sandbox has no session keyring")
    elif outside_serial is not None and inside["keyring"] == str(outside_serial):
        failures.append(f"the sandbox shares the host session keyring ({outside_serial})")
    elif inside.get("keyring-links") != "0":
        failures.append(f"the sandbox session keyring is not empty ({inside.get('keyring-links')} links)")
    for k, what in (("host-pid-visible", "a host process is visible in /proc"),
                    ("host-environ-readable", "a host process environ is readable"),
                    ("host-pid-signalled", "a host process can be signalled"),
                    ("host-shm-visible", "a host /dev/shm file is visible")):
        if k == "host-shm-visible" and not shm_made:
            continue
        if inside.get(k) != "0":
            failures.append(f"{what} inside the sandbox")
    for f in failures:
        print(f"FAIL: {f}")
    if not failures:
        print("sandbox-pid-ipc-keyring: PID, IPC and keyring isolation hold")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
