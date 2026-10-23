#!/usr/bin/env python3
"""Check: the build sandbox cannot use the kernel keyring system calls
(known failure: exits 1 until the sandbox is fixed).

The sandbox gives the build a new, empty session keyring, but keyring access
is checked by kernel uid, and the mapped root inside has the runner's kernel
uid. So the build can still reach the runner's keyrings by serial number:
describe the runner's session keyring and link the runner's user keyring
into its own session keyring, which makes the keys in it its own.

The check takes the serials of this process's session and user keyrings,
runs a probe through sandbox.sh and requires that, inside, keyctl, add_key
and request_key all fail, and that neither host keyring can be described or
linked by serial number.

Exit 0 when all hold, 1 when any fails, 2 when the check cannot run (no
keyrings here, an unsupported architecture, or the sandbox does not start).
Run it locally with `python3 -I checks/sandbox-keyring-syscalls.py`.
"""
import ctypes
import os
import pathlib
import platform
import subprocess
import sys

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
SANDBOX = ROOT / "scripts" / "sandbox.sh"
# add_key, request_key, keyctl
NR = {"x86_64": (248, 249, 250), "aarch64": (217, 218, 219)}
KEYCTL_GET_KEYRING_ID = 0
KEYCTL_DESCRIBE = 6
KEYCTL_LINK = 8
KEY_SPEC_SESSION_KEYRING = -3
KEY_SPEC_USER_KEYRING = -4

libc = ctypes.CDLL(None, use_errno=True)
libc.syscall.restype = ctypes.c_long


def call(nr, *args):
    conv = [ctypes.c_long(a) if isinstance(a, int) else a for a in args]
    r = libc.syscall(ctypes.c_long(nr), *conv)
    return r if r >= 0 else -ctypes.get_errno()


def probe(nrs, host_session, host_user):
    add_key, request_key, keyctl = nrs
    buf = ctypes.create_string_buffer(256)
    results = {
        "keyctl": call(keyctl, KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 0),
        "add_key": call(add_key, b"user", b"pb-sandbox-probe", b"x", 1, KEY_SPEC_SESSION_KEYRING),
        "request_key": call(request_key, b"user", b"pb-sandbox-probe", None, 0),
        "describe-host-session": call(keyctl, KEYCTL_DESCRIBE, int(host_session), buf, 256),
        "describe-host-user": call(keyctl, KEYCTL_DESCRIBE, int(host_user), buf, 256),
        "link-host-session": call(keyctl, KEYCTL_LINK, int(host_session), KEY_SPEC_SESSION_KEYRING),
        "link-host-user": call(keyctl, KEYCTL_LINK, int(host_user), KEY_SPEC_SESSION_KEYRING),
    }
    # request_key for a key that does not exist fails with ENOKEY when the
    # call itself is allowed; only EPERM or ENOSYS mean it was refused.
    print(" ".join(f"{k}={v}" for k, v in results.items()))
    return 0


def main():
    nrs = NR.get(platform.machine())
    if nrs is None:
        print(f"unsupported architecture {platform.machine()}; check not run", file=sys.stderr)
        return 2
    if len(sys.argv) == 4 and sys.argv[1] == "--probe":
        return probe(nrs, sys.argv[2], sys.argv[3])
    keyctl = nrs[2]
    host_session = call(keyctl, KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 1)
    host_user = call(keyctl, KEYCTL_GET_KEYRING_ID, KEY_SPEC_USER_KEYRING, 1)
    if host_session < 0 or host_user < 0:
        print("no session or user keyring on the host; check not run", file=sys.stderr)
        return 2
    env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
    try:
        r = subprocess.run(
            [str(SANDBOX), "--", sys.executable, "-I", str(pathlib.Path(__file__).resolve()),
             "--probe", str(host_session), str(host_user)],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            timeout=300, check=False)
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"cannot run the sandbox: {e}", file=sys.stderr)
        return 2
    if r.returncode != 0:
        print(f"the sandbox failed (exit {r.returncode}); check not run", file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        return 2
    line = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    inside = dict(kv.split("=", 1) for kv in line.split() if "=" in kv)
    if len(inside) != 7:
        print(f"unexpected probe output: {line!r}", file=sys.stderr)
        return 2
    refused = {str(-1), str(-38)}  # -EPERM, -ENOSYS
    failures = [f"{k} was not refused inside the sandbox (result {v})"
                for k, v in inside.items() if v not in refused]
    for f in failures:
        print(f"FAIL: {f}")
    if not failures:
        print("sandbox-keyring-syscalls: keyring system calls are refused")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
