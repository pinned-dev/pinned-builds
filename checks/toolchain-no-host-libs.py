#!/usr/bin/env python3
"""Check: a recipe cannot link a library from the host's default linker
search directories (known failure: exits 1 until the link is hermetic).

The toolchain's ld was built without a sysroot, so its built-in search
directories (/usr/lib, /usr/local/lib, /usr/x86_64-pc-linux-gnu/lib and
lib64) are host paths that --sysroot does not prefix. Any -l<name> that the
toolchain does not ship as a link name is then taken from the host: on a
host with /usr/lib/libz.so, `target_link_libraries(t z)` links the host's
zlib.

The check copies the repository's scripts into a scratch tree and builds,
with build-recipe.sh, a recipe whose CMake project links -lz. The toolchain
ships no libz.so link name, so the link must fail with "cannot find -lz".

It needs a host where the leak is observable: a libz.so in /usr/lib or
/usr/local/lib (exit 2 otherwise). It also needs an installed pinned
toolchain (PB_CHECK_TOOLCHAIN=<dir>) and TMPDIR outside the directories the
sandbox hides. Exit 0 when the link is refused, 1 when it links the host's
library, 2 when the check cannot run.
Run it locally with
`PB_CHECK_TOOLCHAIN=<dir> TMPDIR=<dir> python3 -I checks/toolchain-no-host-libs.py`.
"""

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
RECIPE = "pb-check-no-host-libs"

BUILD_SH = r"""# shellcheck shell=bash
. "$PB_LIB"
mkdir -p "$PB_BUILD/src"
cat > "$PB_BUILD/src/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.20)
project(nohostlibs CXX)
add_executable(t t.cc)
target_link_libraries(t z)
EOF
printf 'extern "C" const char* zlibVersion();\nint main() { return zlibVersion() == 0; }\n' > "$PB_BUILD/src/t.cc"
if pb_cmake nohostlibs "$PB_BUILD/src" > "$PB_BUILD/log" 2>&1; then
  echo "host input: -lz linked from outside the toolchain" >&2
  exit 1
fi
grep -q 'cannot find -lz' "$PB_BUILD/log" || { tail -20 "$PB_BUILD/log" >&2; exit 3; }
exit 0
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
    host = [p for p in ("/usr/lib/libz.so", "/usr/local/lib/libz.so") if os.path.exists(p)]
    if not host:
        print("no libz.so in /usr/lib or /usr/local/lib here, so a leak is not observable;"
              " check not run", file=sys.stderr)
        return 2
    tc = os.environ.get("PB_CHECK_TOOLCHAIN", "")
    if not tc or not os.path.isdir(tc):
        print("set PB_CHECK_TOOLCHAIN to an installed pinned toolchain; check not run", file=sys.stderr)
        return 2
    base = scratch_base()
    if base is None:
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    tmp = tempfile.mkdtemp(prefix="pb-nohostlibs.", dir=base)
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
        env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
        r = subprocess.run(
            [str(tree / "scripts" / "build-recipe.sh"), RECIPE, tc, str(pathlib.Path(tmp, "work")),
             str(pathlib.Path(tmp, "manifest.json"))],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            timeout=900, check=False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if r.returncode == 0:
        print("toolchain-no-host-libs: -lz is refused (not in the toolchain)")
        return 0
    if "host input: -lz linked from outside the toolchain" in r.stderr:
        print(f"FAIL: -lz linked from the host ({', '.join(host)} is there), not refused")
        return 1
    print(f"the build did not get to the link test (exit {r.returncode}); check not run", file=sys.stderr)
    print(r.stderr[-1500:], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
