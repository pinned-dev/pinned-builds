#!/usr/bin/env python3
"""Give a command a new, empty session keyring, or show the current one:

    session-keyring.py CODE COMMAND [ARGS...]
    session-keyring.py --show

The first form joins a new anonymous session keyring with
keyctl(KEYCTL_JOIN_SESSION_KEYRING, NULL), checks that it is the session
keyring now and that it is empty, and then executes COMMAND, which inherits
it. It fails closed: if any of that fails (no keyrings in the kernel, the
call refused, an unsupported architecture), it exits with CODE and COMMAND
does not run.

The second form prints "<serial> <number of links>" for the session keyring
(the user session keyring if the process has none), or exits 1.
"""
import ctypes
import os
import platform
import sys

SYS_KEYCTL = {"x86_64": 250, "aarch64": 219}
KEYCTL_GET_KEYRING_ID = 0
KEYCTL_JOIN_SESSION_KEYRING = 1
KEYCTL_READ = 11
KEY_SPEC_SESSION_KEYRING = -3


def keyctl(op, a2=0, a3=0, a4=0):
    nr = SYS_KEYCTL.get(platform.machine())
    if nr is None:
        raise OSError(f"unsupported architecture {platform.machine()}")
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long
    r = libc.syscall(ctypes.c_long(nr), ctypes.c_long(op), ctypes.c_long(a2),
                     ctypes.c_long(a3), ctypes.c_long(a4))
    if r < 0:
        e = ctypes.get_errno()
        raise OSError(e, os.strerror(e))
    return r


def current():
    """(serial, number of links) of the session keyring."""
    serial = keyctl(KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 0)
    size = keyctl(KEYCTL_READ, serial, 0, 0)  # a NULL buffer returns the size
    return serial, size // 4


def main():
    if sys.argv[1:] == ["--show"]:
        try:
            print("%d %d" % current())
        except OSError as e:
            print(f"session-keyring: {e}", file=sys.stderr)
            return 1
        return 0
    if len(sys.argv) < 3 or not sys.argv[1].isdigit():
        print("usage: session-keyring.py CODE COMMAND [ARGS...] | --show", file=sys.stderr)
        return 2
    code = int(sys.argv[1])
    try:
        new = keyctl(KEYCTL_JOIN_SESSION_KEYRING, 0)
        serial, links = current()
        if serial != new or links != 0:
            raise OSError(f"the session keyring is {serial} with {links} links, not the new empty {new}")
    except OSError as e:
        print(f"session-keyring: cannot join a new session keyring: {e}", file=sys.stderr)
        return code
    try:
        os.execvp(sys.argv[2], sys.argv[2:])
    except OSError as e:
        print(f"session-keyring: cannot run {sys.argv[2]}: {e}", file=sys.stderr)
        return code


if __name__ == "__main__":
    sys.exit(main())
