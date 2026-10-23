#!/usr/bin/env python3
"""Check: every sandbox defence is caught by its own netns-check.sh token
(known failure: exits 1 until the sandbox exit codes are fixed).

For each mutation below, the check copies scripts/ into a scratch tree,
removes one defence from sandbox.sh or deny-keyrings.py (and, where a
direct assertion would fire first, disables that assertion in
netns-check.sh), runs netns-check.sh with a step summary file, and requires
the summary to say "netns-check: FAIL <token> (exit <n>)" with the token
that names exactly that defence. An unmutated control run must PASS first.

This keeps two properties honest: a check that cannot fail (the nested
user namespace checks once always passed, because unshare(1) cannot write a
uid_map on the sandbox's read-only /proc) and a defence whose token does
not reach the summary (an inside assertion whose exit code falls outside
the range sandbox.sh passes on is reported as check-not-run).

A mutation whose text is not found is reported as not applicable and
counts as a failure. Exit 0 when every mutation is caught by its token, 1
when any is not, 2 when the check cannot run (the control run fails, or no
TMPDIR outside the directories the sandbox hides). Run it locally with
`TMPDIR=<dir> python3 -I checks/netns-check-mutations.py [NAME...]`.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
SB, NC, DK = "sandbox.sh", "netns-check.sh", "deny-keyrings.py"

# name: (expected token, [(file, old text, new text), ...])
MUTATIONS = {
    "no-net": ("inside-ifaces", [(SB, "--user --map-root-user --net --mount", "--user --map-root-user --mount")]),
    "no-pid": ("inside-pid-ns", [(SB, "    --pid --fork --kill-child --mount-proc --ipc -- \\", "    --ipc -- \\")]),
    "no-ipc": ("inside-ipc-ns", [(SB, "--mount-proc --ipc -- ", "--mount-proc -- ")]),
    "no-mount-proc": ("inside-proc-not-own", [(SB, "--kill-child --mount-proc --ipc", "--kill-child --ipc")]),
    "no-keyring-join": ("sandbox-session-keyring", [
        (SB, 'python3 -I "$HERE/session-keyring.py" 118 "$HERE/sandbox.sh"', '"$HERE/sandbox.sh"')]),
    "no-ro-root": ("inside-rw-mount", [
        (SB, '  python3 -I "$HERE/mount-setattr.py" ro / || die 112 "cannot make / read-only"', "  :")]),
    "no-caps-drop": ("inside-caps", [
        (SB, "setpriv --no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all --",
         "setpriv --no-new-privs --")]),
    "no-shm-hide": ("inside-ipc-visible", [
        (SB, "for h in /dev/shm /dev/mqueue /dev/pts; do", "for h in /dev/pts; do")]),
    "no-pts-hide": ("inside-host-tty-writable", [
        (SB, "for h in /dev/shm /dev/mqueue /dev/pts; do", "for h in /dev/shm /dev/mqueue; do")]),
    "no-keyring-filter": ("inside-seccomp", [
        (SB, 'setsid --wait -- python3 -I "$HERE/deny-keyrings.py" 119)', "setsid --wait --)")]),
    "filter-allows-add-key": ("inside-add-key-allowed", [
        (DK, "(JEQ_K, 3, 0, add_key),", "(JEQ_K, 3, 0, 0xFFFFFF),")]),
    "filter-allows-request-key": ("inside-request-key-allowed", [
        (DK, "(JEQ_K, 2, 0, request_key),", "(JEQ_K, 2, 0, 0xFFFFFF),")]),
    "filter-allows-keyctl": ("sandbox-keyring-filter", [
        (DK, "(JEQ_K, 1, 0, keyctl),", "(JEQ_K, 1, 0, 0xFFFFFF),")]),
    "filter-allows-x32": ("inside-x32-allowed", [
        (DK, "        p += [(JGE_K, 0, 1, x32), (RET_K, 0, 0, RET_ERRNO | ENOSYS)]", "        pass")]),
    "filter-allows-other-arch": ("inside-i386-allowed", [
        (DK, "        (RET_K, 0, 0, RET_KILL_PROCESS),", "        (RET_K, 0, 0, RET_ALLOW),")]),
    "no-proc-keys-mask": ("inside-proc-keys-visible", [
        (SB, 'then mount --bind /dev/null "$f" || die 111 "cannot mask $f"; fi', "then :; fi")]),
    "no-proc-keys-mask-nested": ("inside-proc-keys-visible", [
        (SB, 'then mount --bind /dev/null "$f" || die 111 "cannot mask $f"; fi', "then :; fi"),
        (NC, '      die proc-keys-visible "$f lists keys inside the sandbox"', "      :")]),
    # The nested user namespace checks must be live: with / left writable and
    # the direct assertions that would fire first disabled, only the nested
    # remount check is left to fail.
    "nested-checks-live": ("inside-nested-remount-root", [
        (SB, '  python3 -I "$HERE/mount-setattr.py" ro / || die 112 "cannot make / read-only"', "  :"),
        (NC, '  [ -z "$found" ] || die rw-mount ', "  true || die rw-mount "),
        (NC, '    if writable "$f"; then die writable-outside', "    if false; then die writable-outside"),
        (NC, "then die remount-root ", "then true; fi; if false; then die remount-root ")]),
}

LINE = re.compile(r"netns-check: (FAIL ([a-z0-9-]+) \(exit ([0-9]+)\)|PASS)")


def scratch_base():
    base = os.environ.get("TMPDIR", "")
    if not base or not os.path.isdir(base):
        return None
    base = os.path.realpath(base)
    home = os.path.realpath(os.environ.get("HOME", "/nonexistent"))
    for hidden in ("/run", "/var/run", "/tmp", "/var/tmp", home):
        if base == hidden or base.startswith(hidden + "/"):
            return None
    return base


def run(base, edits):
    """Run netns-check.sh on a mutated copy; the summary verdict, or None."""
    tmp = tempfile.mkdtemp(prefix="pb-mutation.", dir=base)
    try:
        scripts = pathlib.Path(tmp, "scripts")
        shutil.copytree(ROOT / "scripts", scripts)
        for name, old, new in edits:
            f = scripts / name
            text = f.read_text()
            if text.count(old) != 1:
                return None
            f.write_text(text.replace(old, new))
        summary = pathlib.Path(tmp, "summary")
        summary.write_text("")
        env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
        env["GITHUB_STEP_SUMMARY"] = str(summary)
        subprocess.run([str(scripts / "netns-check.sh")], env=env, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=600, check=False)
        verdicts = [m.group(1) for m in map(LINE.fullmatch, summary.read_text().splitlines()) if m]
        return verdicts[-1] if verdicts else "no verdict"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    names = sys.argv[1:] or list(MUTATIONS)
    unknown = [n for n in names if n not in MUTATIONS]
    if unknown:
        print(f"unknown mutation(s): {' '.join(unknown)}", file=sys.stderr)
        return 2
    base = scratch_base()
    if base is None:
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    control = run(base, [])
    if control != "PASS":
        print(f"control: netns-check.sh does not pass unmutated ({control}); check not run", file=sys.stderr)
        return 2
    failures = 0
    for n in names:
        token, edits = MUTATIONS[n]
        got = run(base, edits)
        if got is None:
            print(f"FAIL: {n}: not applicable (the text to mutate is not in this tree)")
            failures += 1
        elif got.startswith(f"FAIL {token} "):
            print(f"ok: {n}: {got}")
        else:
            print(f"FAIL: {n}: expected FAIL {token}, got {got}")
            failures += 1
    if not failures:
        print(f"netns-check-mutations: all {len(names)} mutations caught by their own token")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
