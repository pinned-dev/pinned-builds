# Native CMake/Ninja capture pilot

The catalog pins 50 public C/C++ packages to exact source commits and SHA-256
archives. The first hosted acceptance run captures Catch2 only. After download,
integrity/privacy validation and a repeated local capture are checked, change
selection.txt from catch2 to all to fan out to the 50-package matrix. The selection
is hashed into result manifests. No private product is used at any stage here.

## What is captured

Original Ninja fragments, CMake File API query/reply, cache, available compilation
database, generated install/test metadata, Ninja target/rule lists, phase outcomes,
source/tool identities, recipe options and required license notices. A hash-pinned
inventory preserves original bytes. A separate graph comparison hash substitutes
only recorded workspace/toolchain/repository roots; it does not replace raw data.
See [POLICY.md](POLICY.md) for publication, limits, exclusions and licenses.

Configure-only does not build package targets, install packages or run their tests.
CMake compiler probes may compile/link/run tiny checks during configuration.
CAPTURED establishes a readable native graph/reference, not build compatibility,
full source closure, Pinned support or complete CMake specification coverage.
Header-only projects may produce no compilation database or compiled targets.

## Commands

List the reviewed default selection or all 50 packages:

```sh
python3 -I scripts/corpus.py plan
python3 -I scripts/corpus.py plan --only all
```

For a local capture, choose an installed native toolchain and a task-owned absolute
scratch root outside the repository. The work/output directories must not exist:

```sh
: "${CORPUS_SCRATCH:?set an absolute task-owned scratch root}"
: "${NATIVE_TOOLCHAIN:?set the installed native toolchain directory}"
mkdir -p "$CORPUS_SCRATCH"
python3 -I scripts/corpus.py run catch2 "$NATIVE_TOOLCHAIN" \
  "$CORPUS_SCRATCH/catch2-work" "$CORPUS_SCRATCH/catch2-capture" --local
python3 -I scripts/corpus.py verify "$CORPUS_SCRATCH/catch2-capture"
```

Local paths are retained in raw metadata; local captures are never approved for
public upload. Hosted captures pass an additional privacy check before upload.
The native-capture workflow runs the reviewed selection on PR/main pushes, with
six jobs maximum in parallel. After integration, manual runs can select a package
or all. Each package produces capture-NAME, including a failure receipt on error.
The native-capture-summary artifact contains metrics.json and summary.md for every
expected package. Missing receipts fail the summary. The summary also validates each downloaded
bundle, so an upload that drops hidden File API files cannot pass. Artifact retention is 14 days.

Validate a downloaded hosted artifact without executing its graph or recipe:

```sh
python3 -I scripts/corpus.py verify /absolute/downloaded-capture \
  --sha256 EXPECTED_CAPTURE_JSON_SHA256 --public
```

The expected digest must come from separately verified provenance. Without it,
verification establishes internal integrity only. Before extraction verify the
GitHub run/event/head/attempt and artifact digest and bound ZIP paths, sizes,
counts and links. PR captures remain development evidence, not trusted-main harvest.
A replay needs exact source/dependencies and a new configure; raw absolute-path
Ninja files are not promised to run in another directory or machine.

## Outcomes and metrics

CAPTURED, CONFIGURE_FAIL, SOURCE_FAIL, TIMEOUT, INFRA_ERROR and CAPTURE_FAIL are
separate. Privacy/capture failures publish only a fixed-code receipt. Build, test
and Pinned status remain NOT_RUN. Counts distinguish packages, captures, graph
nodes/rules, captured files/bytes, target types and declared feature tags. Tags
are intended sample diversity, not proven behavioral coverage or percentages.

New packages add catalog provenance/options/notices and a small recipe directory.
Do not count repeated configurations as new packages. After the graph pilot,
select diverse graphs for full native/private-lab execution and incremental edits;
reduce discovered differences to small regression cases.
