# pinned-builds
Pinned builds

## Recipes and CI

Each directory under `recipes/` is one recipe: `sources.txt` pins every
upstream source archive by URL and SHA-256, and `build.sh` builds it with the
pinned toolchain named in `toolchain.lock` (a release asset of this
repository, verified by digest before use). `.github/workflows/build.yml`
builds every recipe as its own job on GitHub-hosted runners, with a
read-only token and no secrets, and keeps one manifest per recipe (input,
output and toolchain digests, runner image) as `results-<recipe>`.

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
- The third-party libraries that the recipes build keep their own licenses,
  which apply to any artifacts built from them. This repository does not
  redistribute those built artifacts.
