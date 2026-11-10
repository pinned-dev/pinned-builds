# pinned-builds
Pinned builds

This public repository uses public OSS sources and native build tools only.
The private Pinned product source and binary must never be copied, downloaded,
built or executed here or in its GitHub Actions jobs, artifacts or caches.
Product testing happens exclusively in a separate private/local testlab;
its outputs must never be published through this repository. The name
`pinned-toolchain-v2` identifies the existing native toolchain, not the product.

## Recipes and CI

Each directory under `recipes/` is one recipe: `sources.txt` pins every
upstream source archive by URL and SHA-256, and `build.sh` builds it with the
pinned toolchain named in `toolchain.lock` (a release asset of this
repository, verified by digest before use). `.github/workflows/build.yml`
builds every recipe as its own job on GitHub-hosted runners, with a
read-only token and no secrets, and keeps one manifest per recipe (input,
output and toolchain digests, runner image) as `results-<recipe>`.
Sources and the toolchain are downloaded and checked against their pinned
digests before the build; the build itself runs in a sandbox with no network
and its own PID and IPC namespaces and session keyring (`scripts/sandbox.sh`),
so building a recipe locally needs Linux 5.12 or later with unprivileged user
namespaces and keyrings, python3 and, for the check that proves the sandbox
works, a network connection.

### Results policy

- Only `results-<recipe>` manifests from `push` runs on `main` of
  `pinned-dev/pinned-builds` are harvested into `results/`. Manifests from
  pull request runs (including forks) and from manual runs are never
  harvested.
- Any harvesting job checks the run's event, branch and head repository
  before it copies anything, and never uses `pull_request_target`.
- Workflow runs for pull requests from forks need approval from a maintainer
  before they run.

### What a result does and does not show

- **Network isolation is verified.** Every job, and every build, starts with
  `scripts/netns-check.sh`. It proves on the host that the network and the
  probe sockets are reachable there, and then proves inside the build's
  sandbox that they are not. The build does not run if any assertion fails.
- **Build-input control covers what the compiler and the linker report.**
  After a build, `scripts/check-build-inputs.py` rejects any input that the
  compiler (headers) or the linker (objects and libraries) recorded from
  outside the pinned toolchain, the work directory and this repository. A
  build step that reads other host files without reporting them is not
  covered by that check. The sandbox hides exactly `/usr/include` and
  `/usr/local`; the rest of the host filesystem stays readable, including
  the host compiler's own include directories and `/opt`. Known residual:
  a build step that copies a host runtime library into the work directory
  and links the copy is not detected.
- **A result here is not semantic-versioning gate evidence.** A result
  manifest records how one public recipe built on a GitHub-hosted runner.
  It is not used as release or version-gate evidence for any other project.

To build a recipe locally:

```sh
scripts/fetch-toolchain.sh download toolchain.tar.zst
scripts/fetch-toolchain.sh install toolchain.tar.zst "$PWD/pinned-toolchain-v2"
scripts/build-recipe.sh catch2 pinned-toolchain-v2 work-catch2 results/catch2.json
```

## Licensing

- Recipes, scripts and other files in this repository outside `results/`
  are licensed under the Apache License, Version 2.0 (see `LICENSE`).
- Everything under `results/` is dedicated to the public domain under
  CC0 1.0 Universal (SPDX: `CC0-1.0`; see `results/LICENSE`).
- Upstream sources and their SPDX licenses are listed in
  `recipes/*/sources.txt`: currently Catch2 (BSL-1.0), fmt (MIT) and
  spdlog (MIT).
- The third-party libraries that the recipes build keep their own licenses,
  which apply to any artifacts built from them. This repository does not
  redistribute those built artifacts.

## Native CMake/Ninja references

The helpers record each configure/compile/install/consumer invocation separately.
Result manifests retain their v1 schema and add `mode`, `phases` and
`build_input_check`. A phase that did not execute is `NOT_RUN`; a started phase
without a finish event is `INCOMPLETE`. `test` is NOT_RUN unless explicitly run
with `pb_run test <project> <test-command> ...`; a consumer success is separate.
Commands, environment values and raw output are not included in public manifests.

`PB_MODE=configure` stops after the **first project** configures successfully.
For cmake-chain this means fmt only: spdlog needs fmt built/installed first.
That mode does not perform the post-build compiler/linker input check and marks
it NOT_RUN. `PB_MODE=full` is the default. Manual Actions runs can select a mode;
push/PR runs keep the full mode.

Set `PB_REFERENCE_OUT` to a new local directory to retain a reference package:

```sh
PB_MODE=full PB_REFERENCE_OUT="$PWD/catch2-reference" \
  scripts/build-recipe.sh catch2 pinned-toolchain-v2 work-catch2 results/catch2.json
```

The package contains raw generated `*.ninja` fragments, available compilation
database/File API replies, configure and phase argv, the recipe files, toolchain
configuration, tool identities and a hashed file inventory. File API queries are
created before configure. Graphs can contain absolute local paths; replay needs
sources and a new configure, not a path substitution in raw Ninja bytes.
Reference capture is size bounded and rejects symlinks in captured file paths.
A capture error fails the invocation even when the native build passed.

These packages are **local only**. The workflow continues to upload safe JSON
result manifests only. Publishing raw graphs/recipe files requires an explicit
reference artifact policy and correct upstream/repository license notices;
reference packages do not inherit results/CC0 licensing. They contain neither
source archives nor built libraries. Native success grants no Pinned verdict.

Checks: `python3 -I checks/native-reference.py` and
`python3 -I checks/manifest-completeness.py`.
