# Native CMake/Ninja capture pilot

The catalog pins 250 public C/C++ projects to exact source commits and SHA-256
archives. The [single-package acceptance run](https://github.com/pinned-dev/pinned-builds/actions/runs/42795928218)
passed for Catch2: download, integrity/privacy validation and graph comparison
with a repeated local capture. It retained 31 files, 265 Ninja targets, 9 rules
and all four requested File API object kinds. An initial upload omission of
hidden File API files was fixed and is covered by a regression check.

The frozen pilot-50 and expansion-100 campaigns retain the first 100 projects.
expansion-200 selects the next 100 projects; inventory-200 records that historical
primary-project inventory. expansion-250 adds 50 new primary projects and
inventory-250 records all 250. The representative nanopb release-version profile
completes round-trip qualification before the new campaign fan-out. Campaign
definitions alone make no PASS claim.
Campaign files and the selection are hashed into result manifests. No private product is used at any stage here.

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

List the reviewed selection, a campaign, or a deterministic partition:

```sh
python3 -I scripts/corpus.py plan
python3 -I scripts/corpus.py plan --campaign expansion-200
python3 -I scripts/corpus.py plan --campaign expansion-200 --batch 1/2 --scope-output scope.json
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
or a reviewed campaign and optional I/N partition. Each package produces capture-NAME, including a failure receipt on error.
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

## Campaign scope

`plan --only NAME` selects one project; `--only all` selects the catalog.
`--campaign NAME` selects an explicit reviewed JSON inventory in campaigns/.
The two selectors are mutually exclusive. With neither, selection.txt is used.
`--batch I/N` takes the I-th partition of sorted project names, without overlaps
or omissions across all N partitions. Empty or malformed partitions fail closed.
The planner limits a run to 250 captures, below the hosted matrix limit; use more
partitions for a larger catalog. The workflow retains max-parallel 6.

The planner emits a scope with exact package names and catalog SHA-256. Summary
revalidates this scope against the same checkout, rejects duplicates or receipts
from other batches/runs, and lists missing package names. A count alone cannot
prove a subset complete. Summary artifacts retain scope.json alongside metrics.
Declared campaigns are source definitions, not claims that all projects passed.

The private consumer must select the same campaign/partition and preserve the
original run, attempt, source and profile identities. A new campaign does not
rewrite or merge old receipts. One project with several profiles is one project.

The RE2 acceptance run [42823678426](https://github.com/pinned-dev/pinned-builds/actions/runs/42823678426)
completed capture/upload/download validation. Root-only graph hashes differed
because CMake sorts regeneration paths before root substitution. A separate
private comparison view confirmed that only the regeneration dependency/phony
set order changed; command and action input ordering remained exact.
All 50 new profiles also completed a local configure/capture calibration.
XZ uses a declared public issue-tracker contact hook; original capture bytes
and upstream notices are preserved. These checks precede the wider hosted run
and do not claim that the wider run has already passed.

## Source dependencies and contribution lifecycle

Selected PNG/SPNG profiles configure a separately pinned zlib-native source as a
real nested library target. extra_sources declares every alias/URL/commit/archive
hash and license notice; sources.txt must match every declaration in order. The
configure hook resolves ZLIB::ZLIB to an interface linking the actual zlibstatic
source target. No prebuilt library, dummy path or configure-time network is used.
The SimpleIni profile is a real add_subdirectory consumer wrapper; upstream tests
that run unconditionally at top level are excluded by normal parent-project use.

Version-shaped metadata is distinguished narrowly from address literals by the
privacy lexer, with negative regressions retaining URL/host/secret blocking. Raw
capture bytes remain authoritative. See POLICY.md for the exact contexts.

Follow [the full PR/merge workflow](../docs/PR_WORKFLOW.md): reviewed source and
metadata, relevant local/hosted checks, exact-head integration, main CI confirmation,
durable restoration mapping and cleanup. Closing a PR alone is not delivery.
