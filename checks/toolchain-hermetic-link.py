#!/usr/bin/env python3
"""Check: a recipe build links against the pinned toolchain's libc, never the
host's (was a known failure; fixed).

build-recipe.sh stages the compiler's sysroot with symlinks into the
toolchain. The toolchain's libc.so and libm.so are GNU ld scripts that name
/usr/lib/libc.so.6, /usr/lib/libm.so.6 and so on. ld prefixes those paths
with the sysroot only when the script itself lies inside the sysroot, and it
decides that on the script's real path, which the symlinks move into the
toolchain directory. So ld used the HOST's /usr/lib/libc.so.6 and
/usr/lib/libm.so.6: on a host that has them (Arch) every link silently used
the host's glibc, and on one that does not (ubuntu-24.04, which keeps them in
/usr/lib/x86_64-linux-gnu) the first link failed, which is the CMake compiler
check, so every recipe failed at configure. build-recipe.sh now stages lib/
and lib64/ as real directories with the ld scripts copied, and proves a
trivial link hermetic before the build (stage toolchain-sysroot).

The check copies the repository's scripts into a scratch tree, adds a
one-file recipe that links a C++ program with -Wl,--trace, and builds it
with build-recipe.sh. The recipe fails unless every libc, libm, libmvec,
libc_nonshared and dynamic loader input lies under the staged sysroot.

Needs an installed pinned toolchain (PB_CHECK_TOOLCHAIN=<dir>, as installed
by scripts/fetch-toolchain.sh) and TMPDIR outside the directories the sandbox
hides. Exit 0 when the link is hermetic, 1 when it is not, 2 when the check
cannot run.
Run it locally with
`PB_CHECK_TOOLCHAIN=<dir> TMPDIR=<dir> python3 -I checks/toolchain-hermetic-link.py`.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
RECIPE = "pb-check-hermetic-link"

BUILD_SH = r"""# shellcheck shell=bash
. "$PB_LIB"
pb_stage compile
printf 'int main() { return 0; }\n' > "$PB_BUILD/t.cc"
"$PB_TOOLCHAIN/host-utils/bin/gcc-16/bin/g++" --sysroot="$PB_WORK/sysroot" \
  "$PB_BUILD/t.cc" -o "$PB_BUILD/t" -Wl,--trace > "$PB_BUILD/trace"
pb_stage smoke-run
bad=0
while read -r input; do
  case "${input##*/}" in
    libc.so*|libm.so*|libmvec.so*|libc_nonshared.a|ld-linux-*.so*)
      case "$input" in
        "$PB_WORK/sysroot/"*) ;;
        *) echo "host input: $input" >&2; bad=1 ;;
      esac ;;
  esac
done < "$PB_BUILD/trace"
exit "$bad"
"""


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


def main():
    tc = os.environ.get("PB_CHECK_TOOLCHAIN", "")
    if not tc or not os.path.isdir(tc):
        print("set PB_CHECK_TOOLCHAIN to an installed pinned toolchain; check not run", file=sys.stderr)
        return 2
    base = scratch_base()
    if base is None:
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    tmp = tempfile.mkdtemp(prefix="pb-hermetic.", dir=base)
    try:
        tree = pathlib.Path(tmp, "repo")
        shutil.copytree(ROOT / "scripts", tree / "scripts")
        shutil.copy2(ROOT / "toolchain.lock", tree / "toolchain.lock")
        (tree / ".github" / "workflows").mkdir(parents=True)
        shutil.copy2(ROOT / ".github" / "workflows" / "build.yml", tree / ".github" / "workflows" / "build.yml")
        rdir = tree / "recipes" / RECIPE
        rdir.mkdir(parents=True)
        (rdir / "sources.txt").write_text("# no sources\n")
        (rdir / "build.sh").write_text(BUILD_SH)
        summary = pathlib.Path(tmp, "summary")
        summary.write_text("")
        env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
        env["GITHUB_STEP_SUMMARY"] = str(summary)
        r = subprocess.run(
            [str(tree / "scripts" / "build-recipe.sh"), RECIPE, tc, str(pathlib.Path(tmp, "work")),
             str(pathlib.Path(tmp, "manifest.json"))],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            timeout=900, check=False)
        lines = summary.read_text().splitlines()
        fail = [ln for ln in lines if ln.startswith("build-recipe: FAIL ")]
        hosts = [ln for ln in r.stderr.splitlines() if ln.startswith("host input: ")]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if r.returncode == 0:
        print("toolchain-hermetic-link: every libc and loader input is the toolchain's")
        return 0
    stage = fail[0].split()[2] if fail else "unknown"
    if stage in ("compile", "smoke-run"):
        print(f"FAIL: the link is not hermetic (build stage {stage}, exit {r.returncode})")
        for h in hosts[:8]:
            print(f"FAIL: {h}")
        if stage == "compile":
            print("FAIL: the link itself failed (no host libc where ld looked for it)")
        return 1
    print(f"the build did not reach the link (stage {stage}, exit {r.returncode}); check not run",
          file=sys.stderr)
    print(r.stderr[-1500:], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
