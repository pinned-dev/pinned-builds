# catch2

Catch2 3.6.0 static libraries, install, then an installed-package consumer test.

Sources and licenses are pinned in sources.txt. The full recipe disables
upstream test suites; smoke-run executes the consumer. Configure-only runs
just the first source project. See the repository README for phase metadata
and local reference capture. Add a scenario when changing options or checks;
do not count a skipped upstream test suite as PASS.

## Hosted pilot

The first pilot is the full Catch2 recipe: configure, compile, staged install,
configure and compile an installed-package consumer, then execute that consumer
using the native toolchain loader. The consumer contains a Catch2 test assertion.
Upstream Catch2 tests remain disabled and their phase is NOT_RUN.

Pull requests run full recipes automatically. After these helpers are merged,
select **Actions → build → Run workflow**, recipe `catch2`, mode `full` for a
single-recipe rerun. Inspect the per-phase table and PASS/FAIL/NOT_RUN counts
in the job summary, then download `results-catch2` for source/toolchain/recipe
identities and output digests. A failure or an incomplete phase must stay visible;
never count a missing upstream test suite as a successful test run.

Only safe native manifests are uploaded. No Pinned product source, binaries or
product trial outputs participate in this pilot.
