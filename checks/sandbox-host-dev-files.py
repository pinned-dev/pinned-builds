#!/usr/bin/env python3
"""Check: a build step cannot copy the host's headers or /usr/local files
into the work directory (was a known failure; fixed: sandbox.sh hides
/usr/include and /usr/local under read-only, empty tmpfs mounts).

The input check after the build covers every file the compiler and the
linker record. A build step that first copies a host file into the build
directory (a CMake add_custom_command, an execute_process, or a line of
build.sh) and then uses the copy passes it, because the copy lies inside
the work directory. The host filesystem is read-only in the sandbox, but
readable.

The check copies the repository's scripts into a scratch tree and builds,
with build-recipe.sh, a recipe whose CMake project has a custom command
that copies a host header from /usr/include (and a file from /usr/local, if
the host has one) into the build directory, as a real build step would.
The recipe fails if any copy succeeded.

Needs a host header in /usr/include (exit 2 otherwise), an installed pinned
toolchain (PB_CHECK_TOOLCHAIN=<dir>) and TMPDIR outside the directories the
sandbox hides. Exit 0 when the host files cannot be read, 1 when a copy
succeeds, 2 when the check cannot run.
Run it locally with
`PB_CHECK_TOOLCHAIN=<dir> TMPDIR=<dir> python3 -I checks/sandbox-host-dev-files.py`.
"""


import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
RECIPE = "pb-check-host-dev-files"

BUILD_SH = r"""# shellcheck shell=bash
. "$PB_LIB"
mkdir -p "$PB_BUILD/src"
cat > "$PB_BUILD/src/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.20)
project(hostdevfiles C)
set(copied "")
foreach(f IN LISTS HOST_FILES)
  get_filename_component(n "${f}" NAME)
  add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/copied-${n}"
    COMMAND "${CMAKE_COMMAND}" -E copy "${f}" "${CMAKE_BINARY_DIR}/copied-${n}")
  list(APPEND copied "${CMAKE_BINARY_DIR}/copied-${n}")
endforeach()
add_custom_target(copy_host_files ALL DEPENDS ${copied})
# (one compiled program, so the build has a dependency log to check)
file(WRITE "${CMAKE_BINARY_DIR}/t.c" "int main(void) { return 0; }\n")
add_executable(t "${CMAKE_BINARY_DIR}/t.c")
EOF
pb_cmake hostdevfiles "$PB_BUILD/src" "-DHOST_FILES=@HOST_FILES@" > "$PB_BUILD/log" 2>&1 || true
bad=0
for f in "$PB_BUILD"/hostdevfiles/copied-*; do
  if [ -f "$f" ]; then echo "host input: copied ${f##*/copied-} from the host" >&2; bad=1; fi
done
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


def host_files():
    """A regular header in /usr/include and a regular file under /usr/local."""
    found = []
    for top, pick in (("/usr/include", lambda n: n.endswith(".h")), ("/usr/local", lambda n: True)):
        for dirpath, dirs, files in os.walk(top):
            dirs.sort()
            hit = next((os.path.join(dirpath, f) for f in sorted(files)
                        if pick(f) and os.path.isfile(os.path.join(dirpath, f))
                        and not os.path.islink(os.path.join(dirpath, f))), None)
            if hit:
                found.append(hit)
                break
    return found if found and found[0].startswith("/usr/include/") else []


def main():
    host = host_files()
    if not host:
        print("no header in /usr/include here, so a leak is not observable; check not run",
              file=sys.stderr)
        return 2
    tc = os.environ.get("PB_CHECK_TOOLCHAIN", "")
    if not tc or not os.path.isdir(tc):
        print("set PB_CHECK_TOOLCHAIN to an installed pinned toolchain; check not run", file=sys.stderr)
        return 2
    base = scratch_base()
    if base is None:
        print("set TMPDIR to a directory outside /run, /tmp, /var/tmp and $HOME", file=sys.stderr)
        return 2
    tmp = tempfile.mkdtemp(prefix="pb-hostdev.", dir=base)
    try:
        tree = pathlib.Path(tmp, "repo")
        shutil.copytree(ROOT / "scripts", tree / "scripts")
        shutil.copy2(ROOT / "toolchain.lock", tree / "toolchain.lock")
        (tree / ".github" / "workflows").mkdir(parents=True)
        shutil.copy2(ROOT / ".github" / "workflows" / "build.yml", tree / ".github" / "workflows" / "build.yml")
        rdir = tree / "recipes" / RECIPE
        rdir.mkdir(parents=True)
        (rdir / "sources.txt").write_text("# no sources\n")
        (rdir / "build.sh").write_text(BUILD_SH.replace("@HOST_FILES@", ";".join(host)))
        env = {k: v for k, v in os.environ.items() if not k.startswith("GITHUB_")}
        r = subprocess.run(
            [str(tree / "scripts" / "build-recipe.sh"), RECIPE, tc, str(pathlib.Path(tmp, "work")),
             str(pathlib.Path(tmp, "manifest.json"))],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            timeout=900, check=False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if r.returncode == 0:
        print(f"sandbox-host-dev-files: the host files ({', '.join(host)}) cannot be read in the sandbox")
        return 0
    copied = [ln for ln in r.stderr.splitlines() if ln.startswith("host input: copied ")]
    if copied:
        for ln in copied:
            print(f"FAIL: a build step {ln[len('host input: '):]}")
        return 1
    print(f"the build failed for another reason (exit {r.returncode}); check not run", file=sys.stderr)
    print(r.stderr[-1500:], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
