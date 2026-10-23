#!/usr/bin/env python3
"""Reject a build that read any input from outside the allowed trees:

    check-build-inputs.py --ninja NINJA --allow DIR [--allow DIR]... BUILD_DIR...

For every CMake/Ninja build directory given, `ninja -t deps` lists what
each compile and link step read, as recorded from the compiler's and the
linker's own dependency output (headers through -MD, link inputs through
ld --dependency-file). Every one of those paths, resolved, must lie under one
of the --allow directories (the toolchain, the work directory, the
repository).

Exit 0 when every input is allowed, 1 when one is not (the first few are
named on stderr), 2 when a build directory has no dependency log or ninja
fails.
"""
import argparse
import os
import subprocess
import sys


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ninja", required=True)
    p.add_argument("--allow", action="append", required=True)
    p.add_argument("build_dirs", nargs="+")
    a = p.parse_args()
    allowed = [os.path.realpath(d) for d in a.allow]
    bad, total = [], 0
    for d in a.build_dirs:
        if not os.path.isfile(os.path.join(d, ".ninja_deps")):
            print(f"check-build-inputs: no dependency log in {d}", file=sys.stderr)
            return 2
        r = subprocess.run([a.ninja, "-C", d, "-t", "deps"], stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, text=True, check=False)
        if r.returncode != 0:
            print(f"check-build-inputs: ninja -t deps failed in {d}: {r.stderr.strip()}", file=sys.stderr)
            return 2
        for line in r.stdout.splitlines():
            if not line.startswith(" ") or not line.strip():
                continue
            path = os.path.realpath(os.path.join(d, line.strip()))
            total += 1
            if not any(path == x or path.startswith(x + "/") for x in allowed):
                bad.append(path)
    for path in sorted(set(bad))[:10]:
        print(f"check-build-inputs: input outside the toolchain and work trees: {path}", file=sys.stderr)
    if bad:
        return 1
    print(f"check-build-inputs: {total} recorded inputs, all inside the allowed trees")
    return 0


if __name__ == "__main__":
    sys.exit(main())
