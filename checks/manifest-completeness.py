#!/usr/bin/env python3
"""Check: the results manifest records every script that shapes a build.

scripts/write-manifest.py hashes a fixed list of files into each results
manifest. The check collects every file under scripts/ that the workflow,
build-recipe.sh, sandbox.sh, netns-check.sh or recipe-lib.sh runs or sources
(as `$HERE/<file>`, `$ROOT/scripts/<file>` or `scripts/<file>`), and
requires each one, and those five files themselves, to be in that list.
It would have caught the sandbox helpers (mount-setattr.py,
session-keyring.py, deny-keyrings.py, nested-userns.py) missing from the
manifest, and it guards future helpers.

Exit 0 when the list is complete, 1 when a script is missing from it, 2 when
the list cannot be found.
Run it with `python3 -I checks/manifest-completeness.py`.
"""
import pathlib
import re
import sys

sys.dont_write_bytecode = True

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUNNERS = [".github/workflows/build.yml", "scripts/build-recipe.sh", "scripts/sandbox.sh",
           "scripts/netns-check.sh", "scripts/recipe-lib.sh"]
REF = re.compile(r'(?:\$HERE/|\$ROOT/scripts/|\$\{HERE\}/|(?<![\w/.$-])scripts/)([A-Za-z0-9][A-Za-z0-9._-]*)')


def manifest_list():
    text = (ROOT / "scripts" / "write-manifest.py").read_text()
    m = re.search(r"for rel in \(([^)]*)\)", text)
    if not m:
        return None
    return set(re.findall(r'"([^"]+)"', m.group(1)))


def main():
    listed = manifest_list()
    if listed is None:
        print("cannot find the script list in scripts/write-manifest.py", file=sys.stderr)
        return 2
    needed = set(RUNNERS)
    for r in RUNNERS:
        for name in REF.findall((ROOT / r).read_text()):
            if (ROOT / "scripts" / name).is_file():
                needed.add(f"scripts/{name}")
    missing = sorted(needed - listed)
    for m in missing:
        print(f"FAIL: {m} shapes the build but is not recorded in the results manifest")
    if not missing:
        print(f"manifest-completeness: all {len(needed)} scripts that shape a build are recorded")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
