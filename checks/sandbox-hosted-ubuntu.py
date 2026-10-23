#!/usr/bin/env python3
"""Check: the build sandbox on ubuntu-24.04 (was a known failure; fixed).

The first hosted run of the build workflow failed in both build jobs at
"Prove the build sandbox has no network" (scripts/netns-check.sh). This check
reproduces the two ubuntu-24.04 differences locally, without a sysctl or root:

A. mount(8) from util-linux 2.39.3 (ubuntu-24.04) silently ignores the
   "=recursive" in "remount,bind,ro=recursive": it issues a plain mount(2)
   remount of / alone, so every submount, including the scripts directory
   bound back into the sandbox, stays writable and netns-check.sh inside
   fails. A shim mount(8) that drops "=recursive" the same way is put first
   on PATH; netns-check.sh must still pass, so the sandbox must not depend
   on mount(8) honouring "=recursive".

B. When the sandbox cannot be set up, the step summary must name the failed
   assertion with a fixed token only (no path, no environment), because raw
   CI logs are not read. Mount operations are denied with a Landlock domain
   (the shape of ubuntu-24.04's AppArmor unprivileged_userns profile: the
   user namespace is created, but it cannot mount); netns-check.sh must fail
   and write exactly one sanitized "netns-check: FAIL <token>" line to
   GITHUB_STEP_SUMMARY.

Exit 0 when both hold, 1 when either fails again, 2 when the check cannot
run (no unprivileged user namespaces, no Landlock, no TMPDIR outside the
directories the sandbox hides). Run it locally with
`TMPDIR=<dir> python3 -I checks/sandbox-hosted-ubuntu.py`.
"""
import ctypes
import os
import pathlib
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
NETNS_CHECK = ROOT / "scripts" / "netns-check.sh"
SUMMARY_LINE = re.compile(r"netns-check: (FAIL [a-z0-9-]+ \(exit [0-9]+\)|PASS|host userns: [a-z0-9_=-]+( [a-z0-9_=-]+)*)")

SHIM = """#!/bin/sh
# util-linux 2.39.3 behaviour: the "=recursive" qualifier is ignored.
for a in "$@"; do
  shift
  set -- "$@" "$(printf '%s' "$a" | sed -e 's/ro=recursive/ro/g' -e 's/rw=recursive/rw/g')"
done
exec /usr/bin/mount "$@"
"""


def landlock_deny_mounts():
    """preexec: no_new_privs and a Landlock domain (denies mount(2))."""
    nr = {"x86_64": (444, 446), "aarch64": (444, 446)}.get(platform.machine())
    if nr is None:
        os._exit(97)
    libc = ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long

    class Attr(ctypes.Structure):
        _fields_ = [("handled_access_fs", ctypes.c_uint64)]

    attr = Attr(1 << 11)  # LANDLOCK_ACCESS_FS_MAKE_BLOCK only
    fd = libc.syscall(nr[0], ctypes.byref(attr), ctypes.sizeof(attr), 0)
    if fd < 0 or libc.prctl(38, 1, 0, 0, 0) != 0 or libc.syscall(nr[1], fd, 0) != 0:
        os._exit(97)
    os.close(fd)


def scratch_dir():
    base = os.environ.get("TMPDIR", "")
    home = os.path.realpath(os.environ.get("HOME", "/nonexistent"))
    if not base or not os.path.isdir(base):
        return None
    base = os.path.realpath(base)
    for hidden in ("/run", "/var/run", "/tmp", "/var/tmp", home):
        if base == hidden or base.startswith(hidden + "/"):
            return None
    return tempfile.mkdtemp(prefix="pb-hosted-ubuntu.", dir=base)


def run(env, preexec=None):
    return subprocess.run([str(NETNS_CHECK)], env=env, preexec_fn=preexec,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=300, check=False)


def main():
    if not shutil.which("unshare") or not os.path.exists("/usr/bin/mount"):
        print("unshare or /usr/bin/mount missing; check not run", file=sys.stderr)
        return 2
    tmp = scratch_dir()
    if tmp is None:
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    failures = []
    try:
        base_env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}

        # Control: the sandbox works here at all.
        r = run(base_env)
        if r.returncode != 0:
            print(f"netns-check.sh fails on this host without any emulation (exit {r.returncode});"
                  " check not run", file=sys.stderr)
            print(r.stderr[-1500:], file=sys.stderr)
            return 2

        # A: mount(8) that ignores "=recursive".
        shim_dir = pathlib.Path(tmp, "shim")
        shim_dir.mkdir()
        shim = shim_dir / "mount"
        shim.write_text(SHIM)
        shim.chmod(stat.S_IRWXU)
        env = dict(base_env, PATH=f"{shim_dir}:{base_env.get('PATH', '/usr/bin:/bin')}")
        r = run(env)
        if r.returncode != 0:
            last = (r.stderr.strip().splitlines() or [""])[0:3]
            failures.append("A: with a mount(8) that ignores =recursive (util-linux 2.39.3),"
                            f" netns-check.sh fails (exit {r.returncode}): {' | '.join(last)}")

        # B: mounts denied in the user namespace; summary names the assertion.
        summary = pathlib.Path(tmp, "step-summary")
        summary.write_text("")
        env = dict(base_env, GITHUB_STEP_SUMMARY=str(summary))
        r = run(env, landlock_deny_mounts)
        if r.returncode == 97:
            print("Landlock is not available; check B not run", file=sys.stderr)
            return 2
        if r.returncode == 0:
            print("netns-check.sh passed with mounts denied; the emulation did not work", file=sys.stderr)
            return 2
        lines = summary.read_text().splitlines()
        fails = [ln for ln in lines if ln.startswith("netns-check: FAIL ")]
        bad = [ln for ln in lines if not SUMMARY_LINE.fullmatch(ln)]
        if len(fails) != 1 or bad:
            failures.append(f"B: netns-check.sh failed (exit {r.returncode}) but the step summary has"
                            f" {len(fails)} FAIL line(s) and {len(bad)} line(s) not of the sanitized form"
                            f" ({len(lines)} line(s) in all)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in failures:
        print(f"FAIL: {f}")
    if not failures:
        print("sandbox-hosted-ubuntu: A and B hold")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
