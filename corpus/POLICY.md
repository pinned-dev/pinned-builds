# Public native capture policy, v1

This corpus contains public OSS configuration/build metadata produced by native
CMake/Ninja. The private Pinned product source, binaries, credentials and trial
outputs are excluded from repositories, jobs, artifacts, caches and releases.

## Artifact allowlist

A capture artifact contains capture.json and a bounded native reference directory:
original generated Ninja fragments, CMake cache/install/test metadata,
compile_commands.json when generated, File API reply JSON, native Ninja target
and rule listings, phase commands/results, the generated toolchain configuration,
public recipe/catalog files and required license notices. File API queries are
submitted before configuration. Absolute paths from the disposable generic hosted
runner may appear. Raw bytes are retained; path normalization must use a separate
view. Archives, expanded upstream source trees, object files, built libraries,
executables, environment dumps and raw configure/build logs are excluded.

Each reference file has a SHA-256 and size. Capture/upload inputs must be regular
files with no symlink ancestors, at most 10,000 files and 128 MiB in total per
package. A privacy check blocks known credential patterns, private local paths,
internal hostnames, IP literals and personal email addresses. Public upstream
license notices retain required author/copyright/email text. Public OSS project
and repository identities are intentional provenance, not private product data.
These automated checks supplement review; they cannot identify every arbitrary
personal name. Documentation and new commit metadata must also be reviewed.

If privacy or capture validation fails, only the fixed-code failure receipt is
published. Partial payloads and logs are not uploaded. Local captures with private
workspace paths remain local and are not approved for publication.

## Licensing

These artifacts are not covered by results/CC0. Repository recipes/helpers keep
the Apache-2.0 license. Upstream-derived material retains the applicable upstream
terms; the catalog records the declared source license and each bundle includes
selected upstream LICENSE/COPYING/NOTICE files. These root notices do not assert
that every file in an upstream repository has the same license. No upstream
source archive or built package is redistributed. CMake generated metadata may
include public upstream values and command text, so keep the notices with it.

## Results and retention

CAPTURED means successful native configure/generate, readable Ninja graph,
required File API replies, complete capture inventory and successful publication
checks. It does not mean a package was built or tested. Configure may itself run
compiler feature probes. Header-only projects may have no compilation database.
CONFIGURE_FAIL, SOURCE_FAIL, TIMEOUT, INFRA_ERROR and CAPTURE_FAIL are explicit
non-success outcomes. Later phases and the Pinned product are NOT_RUN.

PR results are development evidence and are not harvested as trusted-main data.
Use one configure profile per package initially; options and toolchain identity
are part of the sample. Artifacts expire after 14 days. Cache is not evidence.
Only selected verified snapshots should later be promoted to durable storage.
