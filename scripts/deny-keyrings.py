#!/usr/bin/env python3
"""Run a command with the kernel keyring system calls refused, or check that
they are:

    deny-keyrings.py CODE COMMAND [ARGS...]
    deny-keyrings.py --check keyctl|add_key|request_key
    deny-keyrings.py --check describe|link SERIAL

The first form installs a seccomp filter on every thread of this process and
then executes COMMAND, which inherits it for good. The filter:
  - kills the process on any system call made with another architecture's
    calling convention (on x86_64, the i386 one), so the numbers below cannot
    be bypassed;
  - on x86_64, refuses every x32 system call with ENOSYS, as a kernel built
    without x32 does;
  - refuses keyctl, add_key and request_key with EPERM;
  - allows everything else.
Keyring access is checked by kernel uid, which the sandbox shares with the
runner, so without this the build could reach the runner's keyrings by
serial number. no_new_privs must already be set (the sandbox sets it with
setpriv). It fails closed: if no_new_privs is not set, the filter cannot be
installed, or keyctl still works after it, it exits with CODE and COMMAND
does not run.

The --check form exits 0 when that call is refused with EPERM and 1
otherwise (allowed, or refused by the kernel for another reason).
"""
import ctypes
import os
import platform
import struct
import sys

# audit arch, seccomp, add_key, request_key, keyctl, x32 bit (or None)
ARCH = {
    "x86_64": (0xC000003E, 317, 248, 249, 250, 0x40000000),
    "aarch64": (0xC00000B7, 277, 217, 218, 219, None),
}
KEYCTL_GET_KEYRING_ID = 0
KEYCTL_DESCRIBE = 6
KEYCTL_LINK = 8
KEY_SPEC_SESSION_KEYRING = -3
EPERM, ENOSYS = 1, 38

SECCOMP_SET_MODE_FILTER = 1
SECCOMP_FILTER_FLAG_TSYNC = 1
RET_KILL_PROCESS = 0x80000000
RET_ERRNO = 0x00050000
RET_ALLOW = 0x7FFF0000
LD_W_ABS = 0x20  # BPF_LD | BPF_W | BPF_ABS
JEQ_K = 0x15     # BPF_JMP | BPF_JEQ | BPF_K
JGE_K = 0x35     # BPF_JMP | BPF_JGE | BPF_K
RET_K = 0x06     # BPF_RET | BPF_K
OFF_NR, OFF_ARCH = 0, 4  # struct seccomp_data

libc = ctypes.CDLL(None, use_errno=True)
libc.syscall.restype = ctypes.c_long


def call(nr, *args):
    conv = [ctypes.c_long(a) if isinstance(a, int) else a for a in args]
    r = libc.syscall(ctypes.c_long(nr), *conv)
    return r if r >= 0 else -ctypes.get_errno()


def program(arch):
    audit, _, add_key, request_key, keyctl, x32 = arch
    # (code, jt, jf, k); jumps are relative to the next instruction.
    p = [
        (LD_W_ABS, 0, 0, OFF_ARCH),
        (JEQ_K, 1, 0, audit),
        (RET_K, 0, 0, RET_KILL_PROCESS),
        (LD_W_ABS, 0, 0, OFF_NR),
    ]
    if x32 is not None:
        p += [(JGE_K, 0, 1, x32), (RET_K, 0, 0, RET_ERRNO | ENOSYS)]
    p += [
        (JEQ_K, 3, 0, add_key),
        (JEQ_K, 2, 0, request_key),
        (JEQ_K, 1, 0, keyctl),
        (RET_K, 0, 0, RET_ALLOW),
        (RET_K, 0, 0, RET_ERRNO | EPERM),
    ]
    return b"".join(struct.pack("=HBBI", *i) for i in p), len(p)


def install(arch):
    with open("/proc/self/status") as f:
        if "NoNewPrivs:\t1\n" not in f.read():
            raise OSError("no_new_privs is not set")
    code, n = program(arch)
    buf = ctypes.create_string_buffer(code, len(code))

    class Fprog(ctypes.Structure):
        _fields_ = [("len", ctypes.c_ushort), ("filter", ctypes.c_void_p)]

    prog = Fprog(n, ctypes.cast(buf, ctypes.c_void_p))
    r = call(arch[1], SECCOMP_SET_MODE_FILTER, SECCOMP_FILTER_FLAG_TSYNC, ctypes.byref(prog))
    if r != 0:
        raise OSError(f"seccomp: {os.strerror(-r) if r < 0 else f'thread {r} not synchronized'}")
    if call(arch[4], KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 0) != -EPERM:
        raise OSError("keyctl is not refused after the filter was installed")


def check(arch, op, serial):
    _, _, add_key, request_key, keyctl, _ = arch
    buf = ctypes.create_string_buffer(256)
    if op == "keyctl":
        r = call(keyctl, KEYCTL_GET_KEYRING_ID, KEY_SPEC_SESSION_KEYRING, 0)
    elif op == "add_key":
        r = call(add_key, b"user", b"pb-sandbox-probe", b"x", 1, KEY_SPEC_SESSION_KEYRING)
    elif op == "request_key":
        r = call(request_key, b"user", b"pb-sandbox-probe", None, 0)
    elif op == "describe":
        r = call(keyctl, KEYCTL_DESCRIBE, serial, buf, 256)
    else:
        r = call(keyctl, KEYCTL_LINK, serial, KEY_SPEC_SESSION_KEYRING)
    return 0 if r == -EPERM else 1


def main():
    arch = ARCH.get(platform.machine())
    a = sys.argv[1:]
    if a[:1] == ["--check"]:
        ok = (len(a) == 2 and a[1] in ("keyctl", "add_key", "request_key")) or \
             (len(a) == 3 and a[1] in ("describe", "link") and a[2].lstrip("-").isdigit())
        if not ok:
            print("usage: deny-keyrings.py --check OP [SERIAL]", file=sys.stderr)
            return 2
        if arch is None:
            return 1
        return check(arch, a[1], int(a[2]) if len(a) == 3 else 0)
    if len(a) < 2 or not a[0].isdigit():
        print("usage: deny-keyrings.py CODE COMMAND [ARGS...]", file=sys.stderr)
        return 2
    code = int(a[0])
    try:
        if arch is None:
            raise OSError(f"unsupported architecture {platform.machine()}")
        install(arch)
    except OSError as e:
        print(f"deny-keyrings: cannot install the filter: {e}", file=sys.stderr)
        return code
    try:
        os.execvp(a[1], a[1:])
    except OSError as e:
        print(f"deny-keyrings: cannot run {a[1]}: {e}", file=sys.stderr)
        return code


if __name__ == "__main__":
    sys.exit(main())
