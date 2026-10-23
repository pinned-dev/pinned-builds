#!/usr/bin/env bash
# Build one recipe with the pinned toolchain and write its results manifest.
#
#   build-recipe.sh <recipe> <toolchain-dir> <work-dir> <manifest-out>
#
# <toolchain-dir> is an installed pinned-toolchain-v2 tree (see
# fetch-toolchain.sh). <work-dir> must not exist. The manifest is written for
# a failed build too (status FAIL, no outputs); the exit status is the build's.
#
# Optional environment:
#   PB_JOBS                        parallel build jobs (default: nproc)
#   PB_SOURCE_CACHE                directory of source archives named by their
#                                  SHA-256; used instead of downloading, and
#                                  still verified
#   PB_TOOLCHAIN_ARCHIVE_SHA256    digest of the archive <toolchain-dir> was
#                                  installed from (recorded, not trusted for
#                                  anything else)
#   GITHUB_STEP_SUMMARY            if set to a writable file, gets one line
#                                  "build-recipe: host: root=<0|1> cpus=<n>"
#                                  and one line "build-recipe: PASS" or
#                                  "build-recipe: FAIL <stage> (exit <n>)",
#                                  where <stage> is a fixed token, and nothing
#                                  else (no path, no environment, no output)
#
# Stages (the failure tokens): usage, toolchain, sources-download,
# sources-verify, sources-unpack, sandbox-check (netns-check.sh on the host),
# then inside the sandbox either the sandbox stage or assertion that failed
# (sandbox-<id> or inside-<id>, as netns-check.sh names them) or the build
# stage the recipe reached (recipe, configure, compile, install,
# smoke-configure, smoke-compile, smoke-run), and last manifest.
set -euo pipefail
export LC_ALL=C
umask 022

STAGE=usage W=''
BUILD_STAGES=" recipe configure compile install smoke-configure smoke-compile smoke-run "
# summary <line>: one sanitized line for the GitHub step summary, if any.
summary() {
  [[ $1 =~ ^(FAIL\ [a-z0-9-]+\ \(exit\ [0-9]+\)|PASS|host:\ root=[01]\ cpus=[0-9]+)$ ]] || return 0
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f "$GITHUB_STEP_SUMMARY" ] && [ -w "$GITHUB_STEP_SUMMARY" ]; then
    printf 'build-recipe: %s\n' "$1" >> "$GITHUB_STEP_SUMMARY" || true
  fi
}
# finish <exit status>: the EXIT trap; name the failed stage.
finish() {
  local rc=$1 token=$STAGE got=''
  if [ "$rc" -eq 0 ]; then summary PASS; return; fi
  if [ "$STAGE" = build ]; then
    # The recipe writes its stage; only the known tokens are believed.
    # (a regular file only: the build could leave a FIFO or a symlink there)
    if [ -f "$W/.pb-stage" ] && [ ! -L "$W/.pb-stage" ]; then
      got=$(head -c 64 "$W/.pb-stage" 2> /dev/null | head -n 1) || got=''
    fi
    if [ -z "$got" ]; then
      token=$("$ROOT/scripts/netns-check.sh" token "$RC" 2> /dev/null) || token=sandbox-exit
    elif [[ $BUILD_STAGES == *" $got "* ]]; then
      token=$got
    else
      token=recipe
    fi
  fi
  summary "FAIL $token (exit $rc)"
}
trap 'finish $?' EXIT
summary "host: root=$([ "$(id -u)" = 0 ] && echo 1 || echo 0) cpus=$(nproc)"

die() { echo "build-recipe: $*" >&2; exit 2; }
[ $# -eq 4 ] || die "usage: $0 <recipe> <toolchain-dir> <work-dir> <manifest-out>"
RECIPE=$1 TC_IN=$2 W_IN=$3 MANIFEST_OUT=$4

ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
[[ $RECIPE =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad recipe name: $RECIPE"
RDIR=$ROOT/recipes/$RECIPE
if [ ! -f "$RDIR/sources.txt" ] || [ ! -f "$RDIR/build.sh" ]; then
  die "no recipe at $RDIR"
fi
STAGE=toolchain
TC=$(realpath -e "$TC_IN") || die "no toolchain at $TC_IN"
if [ -e "$W_IN" ] || [ -L "$W_IN" ]; then die "work dir exists: $W_IN"; fi
W_PARENT=$(realpath -e "$(dirname "$W_IN")") || die "the parent of $W_IN must exist"
W=$(realpath -m "$W_PARENT/$(basename "$W_IN")")
# The build runs in the sandbox of sandbox.sh, which hides /run first; check
# the resolved paths before anything is created or downloaded.
for p in "$ROOT" "$TC" "$W"; do
  case "$p/" in /run/*|/var/run/*) die "$p is hidden inside the build sandbox; use another directory" ;; esac
done
mkdir "$W"

GCC=$TC/host-utils/bin/gcc-16/bin/gcc
GXX=$TC/host-utils/bin/gcc-16/bin/g++
CMAKE=$TC/host-utils/bin/cmake-4.4.3/bin/cmake
NINJA=$TC/reference-tools/bin/ninja
LOADER=$TC/sysroot/lib/ld-linux-x86-64.so.2
for f in "$GCC" "$GXX" "$CMAKE" "$NINJA" "$LOADER" \
         "$TC/host-utils/bin/ar" "$TC/host-utils/bin/ranlib" "$TC/MANIFEST.sha256"; do
  [ -x "$f" ] || [ -f "$f" ] || die "toolchain is missing $f"
done

mkdir -p "$W/dl" "$W/src" "$W/build" "$W/out/root/pb" "$W/home" "$W/tmp" \
         "$W/sysroot/usr" "$W/hostlibs"

# Staged sysroot: the toolchain's libc.so names /usr/lib/..., and the bundle
# only has lib/ and lib64/. Nothing of the host's /usr/include or /usr/lib is
# visible to the compiler or linker through it.
ln -s "$TC/sysroot/lib" "$W/sysroot/lib"
ln -s "$TC/sysroot/lib64" "$W/sysroot/lib64"
ln -s "$TC/sysroot/lib" "$W/sysroot/usr/lib"

# The compiler and binutils run on the host's loader and libc (they need at
# most GLIBC_2.38), so only the toolchain's non-glibc runtime libraries go on
# their library path. Built programs run on the toolchain's own loader and
# libc instead (pb_exec in recipe-lib.sh).
for lib in libbfd-2.46.1.so libctf.so.0 libsframe.so.3 libgmp.so.10 libisl.so.23 \
           libjansson.so.4 libmpc.so.3 libmpfr.so.6 libstdc++.so.6 libgcc_s.so.1 \
           libz.so.1 libzstd.so.1; do
  [ -f "$TC/sysroot/lib/$lib" ] || die "toolchain is missing sysroot/lib/$lib"
  ln -s "$TC/sysroot/lib/$lib" "$W/hostlibs/$lib"
done

cat > "$W/toolchain.cmake" <<EOF
set(CMAKE_C_COMPILER "$GCC")
set(CMAKE_CXX_COMPILER "$GXX")
set(CMAKE_AR "$TC/host-utils/bin/ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "$TC/host-utils/bin/ranlib" CACHE FILEPATH "")
set(CMAKE_SYSROOT "$W/sysroot")
set(CMAKE_C_FLAGS_INIT "-ffile-prefix-map=$ROOT=/pb-repo -ffile-prefix-map=$W=/pb")
set(CMAKE_CXX_FLAGS_INIT "-ffile-prefix-map=$ROOT=/pb-repo -ffile-prefix-map=$W=/pb")
set(CMAKE_FIND_ROOT_PATH "$W/out/root/pb")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY OFF)
EOF

# Sources: verify the pinned SHA-256 before anything is unpacked.
# sources.txt columns: name sha256 top-level-dir spdx url
STAGE=sources-download
SOURCES_TSV=$W/sources.tsv
: > "$SOURCES_TSV"
while read -r name sha top spdx url; do
  case "$name" in ''|'#'*) continue ;; esac
  [[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad source name: $name"
  [[ $sha =~ ^[0-9a-f]{64}$ ]] || die "bad sha256 for $name"
  [[ $url == https://* ]] || die "source $name: only https URLs are allowed"
  [[ $top =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "bad top-level dir for $name"
  STAGE=sources-download
  a=$W/dl/$sha
  if [ -n "${PB_SOURCE_CACHE:-}" ] && [ -f "$PB_SOURCE_CACHE/$sha" ]; then
    cp "$PB_SOURCE_CACHE/$sha" "$a"
  else
    curl --fail --silent --show-error --location --proto '=https' \
         --retry 3 --retry-delay 5 -o "$a" "$url" || die "download failed: $url"
  fi
  STAGE=sources-verify
  got=$(sha256sum < "$a" | cut -c1-64)
  [ "$got" = "$sha" ] || die "source $name: sha256 mismatch: got $got, pinned $sha"
  STAGE=sources-unpack
  mkdir "$W/src/.x-$name"
  tar -xzf "$a" -C "$W/src/.x-$name" --no-same-owner --no-same-permissions ||
    die "source $name: unpack failed"
  [ "$(ls -A "$W/src/.x-$name")" = "$top" ] || die "source $name: unexpected top-level entries"
  mv "$W/src/.x-$name/$top" "$W/src/$name"
  rmdir "$W/src/.x-$name"
  printf '%s\t%s\t%s\t%s\n' "$name" "$sha" "$spdx" "$url" >> "$SOURCES_TSV"
  echo "build-recipe: source $name sha256=$sha OK"
done < "$RDIR/sources.txt"

# The build itself runs with no network in the sandbox of sandbox.sh: new
# user, network, mount, PID and IPC namespaces, a new session keyring and
# no keyring system calls, no inherited descriptors, the host filesystem
# read-only, /run, /tmp, /var/tmp, $HOME, /dev/shm, /dev/mqueue and
# /dev/pts hidden, no controlling terminal, and only the work directory
# writable. netns-check.sh first runs its
# positive controls on the host, so that the sandbox's own check (run
# inside, before build.sh starts) means something.
STAGE=sandbox-check
"$ROOT/scripts/netns-check.sh" || die "no isolated sandbox for the build"

START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Until the recipe records a stage, a failure is the sandbox's own.
STAGE=build RC=0
rm -f "$W/.pb-stage"
set +e
"$ROOT/scripts/sandbox.sh" --ro "$ROOT" --ro "$TC" --rw "$W" -- env -i \
  PATH=/usr/bin:/bin HOME="$W/home" TMPDIR="$W/tmp" LC_ALL=C TZ=UTC \
  SOURCE_DATE_EPOCH=1 LD_LIBRARY_PATH="$W/hostlibs" \
  PB_LIB="$ROOT/scripts/recipe-lib.sh" PB_RECIPE_DIR="$RDIR" PB_WORK="$W" \
  PB_SRC="$W/src" PB_BUILD="$W/build" PB_OUT="$W/out" PB_PREFIX="$W/out/root/pb" PB_INSTALL_PREFIX=/pb \
  PB_TOOLCHAIN="$TC" PB_TOOLCHAIN_FILE="$W/toolchain.cmake" PB_CMAKE="$CMAKE" \
  PB_NINJA="$NINJA" PB_LOADER="$LOADER" PB_JOBS="${PB_JOBS:-$(nproc)}" \
  bash -euo pipefail "$RDIR/build.sh"
RC=$?
set -e
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATUS=PASS
[ "$RC" -eq 0 ] || STATUS=FAIL
echo "build-recipe: $RECIPE $STATUS (exit $RC)"

STAGE_BUILD=$STAGE
STAGE=manifest
mkdir -p "$(dirname "$MANIFEST_OUT")"
python3 -I "$ROOT/scripts/write-manifest.py" \
  --recipe "$RECIPE" --recipe-dir "$RDIR" --repo-root "$ROOT" \
  --status "$STATUS" --sources "$SOURCES_TSV" --out-dir "$W/out" \
  --toolchain-dir "$TC" --toolchain-lock "$ROOT/toolchain.lock" \
  --toolchain-archive-sha256 "${PB_TOOLCHAIN_ARCHIVE_SHA256:-}" \
  --started "$START" --finished "$END" --output "$MANIFEST_OUT"
echo "build-recipe: manifest $MANIFEST_OUT"
# The exit status is the build's; the summary names its stage.
STAGE=$STAGE_BUILD
exit "$RC"
