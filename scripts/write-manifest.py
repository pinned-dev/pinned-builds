"""Write the results manifest for one recipe build (called by build-recipe.sh).

The manifest holds digests and safe metadata only: no logs, no environment
dump, no absolute paths of the build machine.
"""

import argparse
import hashlib
import json
import os
import platform
import sys

SCHEMA = "pinned-builds/result-manifest/v1"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def tree(root):
    """Every regular file and symlink under root, sorted by relative path."""
    entries = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in dirnames + filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            if os.path.islink(full):
                entries.append({"path": rel, "symlink": os.readlink(full)})
            elif os.path.isfile(full):
                entries.append({"path": rel, "sha256": sha256_file(full),
                                "size": os.path.getsize(full)})
    entries.sort(key=lambda e: e["path"].encode())
    return entries


def aggregate(entries):
    h = hashlib.sha256()
    for e in entries:
        value = e.get("sha256") or "symlink:" + e["symlink"]
        h.update(f"{value}  {e['path']}\n".encode())
    return h.hexdigest()


def lock_values(path):
    values = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key] = value
    return values


def main():
    p = argparse.ArgumentParser()
    for opt in ("recipe", "recipe-dir", "repo-root", "status", "sources", "out-dir",
                "toolchain-dir", "toolchain-lock", "toolchain-archive-sha256",
                "started", "finished", "output"):
        p.add_argument("--" + opt, required=True)
    a = p.parse_args()

    inputs = []
    with open(a.sources, encoding="utf-8") as f:
        for line in f:
            name, sha, spdx, url = line.rstrip("\n").split("\t")
            inputs.append({"name": name, "url": url, "sha256": sha, "license": spdx})

    recipe_files = tree(a.recipe_dir)
    scripts = [{"path": rel, "sha256": sha256_file(os.path.join(a.repo_root, rel))}
               for rel in (".github/workflows/build.yml", "scripts/build-recipe.sh",
                           "scripts/fetch-toolchain.sh", "scripts/netns-check.sh", "scripts/sandbox.sh",
                           "scripts/mount-setattr.py", "scripts/session-keyring.py",
                           "scripts/deny-keyrings.py", "scripts/nested-userns.py",
                           "scripts/check-build-inputs.py",
                           "scripts/recipe-lib.sh", "scripts/write-manifest.py",
                           "toolchain.lock")]

    lock = lock_values(a.toolchain_lock)
    toolchain = {
        "release_tag": lock.get("TOOLCHAIN_TAG"),
        "asset": lock.get("TOOLCHAIN_ASSET"),
        "pinned_sha256": lock.get("TOOLCHAIN_SHA256"),
        # The digest of the archive this toolchain tree was installed from, if
        # the caller verified one; null for a locally provisioned tree.
        "archive_sha256": a.toolchain_archive_sha256 or None,
        "manifest_sha256": sha256_file(os.path.join(a.toolchain_dir, "MANIFEST.sha256")),
    }

    outputs = tree(a.out_dir) if a.status == "PASS" else []
    env = os.environ
    uname = platform.uname()
    manifest = {
        "schema": SCHEMA,
        "evidence_class": "public-corpus",
        "recipe": a.recipe,
        "status": a.status,
        "started": a.started,
        "finished": a.finished,
        "source": {
            "repository": env.get("GITHUB_REPOSITORY"),
            "commit": env.get("GITHUB_SHA"),
            "ref": env.get("GITHUB_REF"),
            "run_id": env.get("GITHUB_RUN_ID"),
            "run_attempt": env.get("GITHUB_RUN_ATTEMPT"),
        },
        "recipe_files": {"files": recipe_files, "digest": aggregate(recipe_files)},
        "scripts": scripts,
        "inputs": inputs,
        "toolchain": toolchain,
        "outputs": {"files": outputs, "digest": aggregate(outputs) if outputs else None},
        "runner": {
            "image_os": env.get("ImageOS"),
            "image_version": env.get("ImageVersion"),
            "runner_os": env.get("RUNNER_OS"),
            "runner_arch": env.get("RUNNER_ARCH"),
            "runner_environment": env.get("RUNNER_ENVIRONMENT"),
            "host_kernel": uname.release,
            "machine": uname.machine,
        },
    }
    tmp = a.output + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, sort_keys=False)
        f.write("\n")
    os.replace(tmp, a.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
