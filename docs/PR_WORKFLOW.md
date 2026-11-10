# Native corpus contribution and merge workflow

The agreed corpus delivery includes a reviewed PR, passing checks, integration
into main, post-merge validation and cleanup. Closing a PR without merging does
not deliver its changes. Carry out already-authorized integration for the same
scope without repeating the same approval. Respect required reviews and branch
rules; do not use force/admin bypasses.

## Source and publication review

Use an isolated branch/worktree and task-owned scratch storage. Inspect the final
diff, all new files, README/AGENTS, recipes, source/license pins and new commit
metadata. Public content uses public OSS and native tools only. Follow AGENTS.md
and corpus/POLICY.md: no private product source/binary/results, private credentials,
local machine details or personal commit identities. Preserve upstream notices.

Use Native Corpus Bot / native-corpus-bot@users.noreply.github.com for both Git
author and committer. Set all four GIT_AUTHOR/GIT_COMMITTER fields explicitly.
An archive actor parameter does not set Git commit identity.

## Relevant preflight

```sh
python3 -B -I checks/corpus.py
python3 -B -I checks/native-reference.py
python3 -B -I checks/manifest-completeness.py
git diff --check
```

Check changed shell recipe syntax and workflow YAML. Confirm upstream options
and notices from the actual pinned source. Run the changed profiles locally.
A new capture mechanism or unusual profile first completes a representative
configure/capture/upload/download/validation/repeat cycle, then a reviewed campaign.

Hosted capture summary validates the downloaded original bundles and exact scope:
hidden File API, inventory/digest/privacy, all expected names, no duplicates or
wrong-batch receipts. Missing/tampered payloads are not success. Preserve explicit
failure receipts; timeout and missing dependencies are not expected rejection.
The separate private consumer independently validates provenance and original
inventories; private results must never be uploaded back to this repository.
CAPTURED is configure/reference evidence, not package build/test/product success.

## Review the concrete PR

Keep the final PR title/body focused on resulting behavior, exact scope, relevant
checks and actual public run links. Remove superseded plans and stale counts.
Include no private evidence/store paths or private product findings.

Immediately before integration, re-read the PR head/base, state, draft status,
mergeability, required reviews and check runs. All required/relevant checks must
pass for that exact HEAD: native build/capture summaries, CodeQL when triggered,
and repository requirements. Pending/failing/missing checks do not count as green.
Read every page of check runs, jobs and artifacts; compare received counts with
total_count and check classic commit statuses. The first CLI/GraphQL rollup may
truncate a large matrix. Verify all relevant workflow conclusions for the exact HEAD.
If head/base changes, reassess the diff and rerun only checks made stale by it.
Retain exact source checkpoints and necessary validated proof before retirement.

## Merge and verify publication

Merge the qualified HEAD into the actual remote main using the supported repo
process and required reviews. Preserve generic merge metadata. If normal direct
push is permitted, an isolated integration checkout can create a normal no-ff
merge with explicit generic author/committer. Verify parents, qualified tree and
fresh PR head/base before a normal push. Concurrent updates must cause a fresh
fetch/review; never force-push. When protection requires a merge queue or GitHub
merge, use that mechanism without bypassing the rules.

Confirm remote main contains the qualified head and GitHub reports PR MERGED with
the actual merge SHA. A local merge or ordinary CLOSED state is not publication.
Then wait for relevant main push validation. Retain run IDs and actual conclusions;
PR success does not silently become main success. Every main capture retains its
new source/event/run/attempt identity. Never relabel an old PR receipt as main data.

## Finish and clean up

Update current progress/bootstrap/restoration pointers and preserve original
immutable receipts. Retain necessary proof once in the designated durable store,
with verified restore and exact repo/ref/commit/hash mapping. Do not copy original
Git configurations, credentials or authority keys into bundles.

After confirmed publication and relevant main CI, complete any repository close
steps. Remove every finished owned review/integration/publication worktree with
Git, without force, and delete only fully merged disposable branches. Delete a
remote feature branch only when its PR is MERGED and it has no active reuse.
Remove owned disposable build/temp/staging/download/cache outputs before the next
implementation or handoff. Keep active or blocked workers only with an owner,
concrete reason and cleanup trigger. Preserve dirty/unmerged unique work, other
sessions' stashes/locks, unknown data and shared primary checkouts. Report removed
and retained data plus remaining disk space.
