#!/usr/bin/env python3
"""Make a mount tree read-only or writable, recursively:

    mount-setattr.py ro|rw PATH

Calls mount_setattr(2) with AT_RECURSIVE directly, so every submount of PATH
changes too. mount(8) is not used for this: util-linux 2.39.3 (ubuntu-24.04)
silently ignores the "=recursive" in "remount,bind,ro=recursive" and
remounts PATH alone. Needs Linux 5.12 or later; fails closed.
"""
import ctypes
import os
import platform
import sys

SYS_MOUNT_SETATTR = {"x86_64": 442, "aarch64": 442}
AT_FDCWD = -100
AT_RECURSIVE = 0x8000
AT_SYMLINK_NOFOLLOW = 0x100
MOUNT_ATTR_RDONLY = 0x1


class MountAttr(ctypes.Structure):
    _fields_ = [("attr_set", ctypes.c_uint64), ("attr_clr", ctypes.c_uint64),
                ("propagation", ctypes.c_uint64), ("userns_fd", ctypes.c_uint64)]


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("ro", "rw"):
        print("usage: mount-setattr.py ro|rw PATH", file=sys.stderr)
        return 2
    nr = SYS_MOUNT_SETATTR.get(platform.machine())
    if nr is None:
        print(f"mount-setattr: unsupported architecture {platform.machine()}", file=sys.stderr)
        return 1
    attr = MountAttr()
    if sys.argv[1] == "ro":
        attr.attr_set = MOUNT_ATTR_RDONLY
    else:
        attr.attr_clr = MOUNT_ATTR_RDONLY
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long
    path = os.fsencode(sys.argv[2])
    r = libc.syscall(ctypes.c_long(nr), ctypes.c_long(AT_FDCWD), ctypes.c_char_p(path),
                     ctypes.c_long(AT_RECURSIVE | AT_SYMLINK_NOFOLLOW), ctypes.byref(attr),
                     ctypes.c_size_t(ctypes.sizeof(attr)))
    if r != 0:
        e = ctypes.get_errno()
        print(f"mount-setattr: {sys.argv[1]} {sys.argv[2]}: {os.strerror(e)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
