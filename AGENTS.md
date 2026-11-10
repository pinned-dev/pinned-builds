# Public repository boundary

This repository is public. The Pinned product is private.

- Never copy, commit, download, build or execute the Pinned product binary or
  product source in this repository or its GitHub Actions jobs.
- Never place product source, binaries, private build logs, product test evidence
  or private repository credentials in this repository's artifacts, caches,
  releases or public result files.
- Recipes use public OSS sources and native CMake/Ninja/compiler tools only.
  The existing name `pinned-toolchain-v2` means a digest-pinned native toolchain;
  it is not permission to include the Pinned product.
- Product trials belong exclusively in the separate private/local testlab.
  Data flows from this public native corpus into that lab. Product trial
  outputs must not be uploaded back into this public repository.

Keep task-created local builds, worktrees and temporary files under
/work/pinlab. Clean only completed owned disposable data; preserve unmerged
source changes and necessary evidence with an owner and cleanup trigger.
