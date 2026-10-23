#!/usr/bin/env python3
"""Try to undo the sandbox from a nested user namespace:

    nested-userns.py remount-rw PATH
    nested-userns.py umount PATH
    nested-userns.py mount-proc

Inside the sandbox /proc is read-only, so unshare(1) cannot write a uid_map
and a nested user namespace stays unmapped. But the process that creates a
user namespace has every capability in it until it calls execve, mapped or
not, so this script makes the calls itself, with no exec in between:
  - remount-rw: unshare a user and a mount namespace, then remount PATH
    read-write (MS_REMOUNT | MS_BIND, without MS_RDONLY);
  - umount: the same, then unmount PATH (MNT_DETACH), which would show what
    is under it;
  - mount-proc: also unshare a PID namespace, and in a child mount a new
    read-only proc over /proc, which would show /proc/keys and
    /proc/key-users unmasked; the kernel refuses it while /proc has masked
    files.

Exit 0 when the attempt is refused (or no nested user namespace can be
created at all), 1 when it succeeds, 2 on a usage error.
"""
import ctypes
import os
import sys

MS_RDONLY, MS_NOSUID, MS_NODEV, MS_NOEXEC = 1, 2, 4, 8
MS_REMOUNT, MS_BIND = 32, 4096
MNT_DETACH = 2

libc = ctypes.CDLL(None, use_errno=True)


def nested(flags):
    try:
        os.unshare(os.CLONE_NEWUSER | os.CLONE_NEWNS | flags)
    except OSError as e:
        print(f"nested-userns: no nested user namespace ({e.strerror}); nothing to undo", file=sys.stderr)
        return False
    return True


def main():
    a = sys.argv[1:]
    if not (len(a) == 2 and a[0] in ("remount-rw", "umount")) and a != ["mount-proc"]:
        print("usage: nested-userns.py remount-rw|umount PATH | mount-proc", file=sys.stderr)
        return 2
    if a[0] == "remount-rw":
        if not nested(0):
            return 0
        return 1 if libc.mount(None, os.fsencode(a[1]), None, MS_REMOUNT | MS_BIND, None) == 0 else 0
    if a[0] == "umount":
        if not nested(0):
            return 0
        return 1 if libc.umount2(os.fsencode(a[1]), MNT_DETACH) == 0 else 0
    if not nested(os.CLONE_NEWPID):
        return 0
    pid = os.fork()
    if pid == 0:
        flags = MS_RDONLY | MS_NOSUID | MS_NODEV | MS_NOEXEC
        os._exit(1 if libc.mount(b"proc", b"/proc", b"proc", flags, None) == 0 else 0)
    _, status = os.waitpid(pid, 0)
    return 1 if os.waitstatus_to_exitcode(status) == 1 else 0


if __name__ == "__main__":
    sys.exit(main())
