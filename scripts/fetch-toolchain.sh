#!/usr/bin/env bash
# Fetch and install the pinned toolchain named in toolchain.lock. Fail closed:
# any digest, layout or manifest mismatch exits non-zero and leaves nothing at
# the destination.
#
#   fetch-toolchain.sh download <archive-out>
#       Anonymous download of TOOLCHAIN_URL; the file appears at <archive-out>
#       only if its SHA-256 equals TOOLCHAIN_SHA256.
#   fetch-toolchain.sh install <archive> <dest-dir>
#       Re-checks the archive digest, unpacks it into a private directory next
#       to <dest-dir>, rejects symlinks and unexpected top-level entries,
#       recomputes MANIFEST.sha256 and LICENSES-MANIFEST.sha256 and only then
#       moves the tree to <dest-dir> (which must not exist).
#
# PB_TOOLCHAIN_URL overrides the download URL (e.g. a file:// mirror); the
# pinned digest still decides.
set -euo pipefail
export LC_ALL=C
umask 022

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOCK=$ROOT/toolchain.lock

die() { echo "fetch-toolchain: reject: $*" >&2; exit 1; }

lock_value() {
  local v
  v=$(grep -E "^$1=" "$LOCK" | head -n 1 | cut -d= -f2-)
  [ -n "$v" ] || die "toolchain.lock has no $1"
  printf '%s' "$v"
}

WANT=$(lock_value TOOLCHAIN_SHA256)
[[ $WANT =~ ^[0-9a-f]{64}$ ]] || die "malformed TOOLCHAIN_SHA256 in toolchain.lock"
URL=${PB_TOOLCHAIN_URL:-$(lock_value TOOLCHAIN_URL)}

digest() { sha256sum < "$1" | cut -c1-64; }

manifest() { # recompute MANIFEST.sha256 (provision-toolchain.sh format) for tree $1
  (cd "$1" && find host-utils sysroot reference-tools -mindepth 1 -print0 | sort -z |
    while IFS= read -r -d '' p; do
      if [ -L "$p" ]; then printf 'symlink %s -> %s\n' "$p" "$(readlink "$p")"
      elif [ -d "$p" ]; then printf 'dir 0755 %s\n' "$p"
      else printf 'file %s %s %s\n' "$(stat -c %a "$p")" "$(sha256sum < "$p" | cut -c1-64)" "$p"
      fi
    done)
}

cmd_download() {
  local out=$1 tmp got
  [ ! -e "$out" ] || die "$out already exists"
  tmp=$(mktemp "$(dirname "$out")/.toolchain.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  curl --fail --silent --show-error --location --proto '=https,file' \
       --retry 3 --retry-delay 5 -o "$tmp" "$URL" || die "download failed: $URL"
  got=$(digest "$tmp")
  [ "$got" = "$WANT" ] || die "sha256 mismatch: got $got, pinned $WANT"
  mv "$tmp" "$out"
  trap - EXIT
  echo "fetch-toolchain: downloaded $out sha256=$got"
}

cmd_install() {
  local archive=$1 dest=$2 got work t bad extra e
  [ -f "$archive" ] || die "no archive at $archive"
  [ ! -e "$dest" ] || die "$dest already exists"
  got=$(digest "$archive")
  [ "$got" = "$WANT" ] || die "sha256 mismatch: got $got, pinned $WANT"
  command -v zstd > /dev/null || die "zstd is not installed"
  mkdir -p "$(dirname "$dest")"
  work=$(mktemp -d "$(dirname "$dest")/.toolchain-x.XXXXXX")
  trap 'rm -rf "$work"' EXIT
  zstd -dc "$archive" | tar -x -C "$work" --no-same-owner --no-same-permissions ||
    die "unpack failed"
  [ "$(ls -A "$work")" = pinned-toolchain-v2 ] || die "unexpected top-level entries"
  t=$work/pinned-toolchain-v2
  # Only regular files and directories, no hardlinks, and only the known
  # top-level entries (the manifests below cover everything else).
  bad=$(find "$t" ! -type f ! -type d -print -quit)
  [ -z "$bad" ] || die "entry that is not a regular file or directory: ${bad#"$work"/}"
  bad=$(find "$t" -type f -links +1 -print -quit)
  [ -z "$bad" ] || die "hardlinked file: ${bad#"$work"/}"
  extra=
  for e in "$t"/* "$t"/.[!.]* "$t"/..?*; do
    [ -e "$e" ] || continue
    case "${e##*/}" in
      host-utils|sysroot|reference-tools|licenses|MANIFEST.sha256|LICENSES-MANIFEST.sha256|NOTICE.md|PROVISION-INFO.txt) ;;
      *) extra="$extra ${e##*/}" ;;
    esac
  done
  [ -z "$extra" ] || die "unexpected entries in pinned-toolchain-v2/: $extra"
  manifest "$t" | cmp -s - "$t/MANIFEST.sha256" || die "MANIFEST.sha256 mismatch"
  [ -f "$t/LICENSES-MANIFEST.sha256" ] || die "LICENSES-MANIFEST.sha256 missing"
  (cd "$t" && sha256sum --quiet --strict -c LICENSES-MANIFEST.sha256) ||
    die "LICENSES-MANIFEST.sha256 mismatch"
  # Every file outside MANIFEST.sha256's scope must be listed in
  # LICENSES-MANIFEST.sha256 (except the two manifests and PROVISION-INFO.txt).
  extra=$(cd "$t" && { find licenses -type f; ls NOTICE.md; } | LC_ALL=C sort |
    comm -23 - <(sed 's/^[0-9a-f]\{64\}  //' LICENSES-MANIFEST.sha256 | LC_ALL=C sort))
  [ -z "$extra" ] || die "files not covered by LICENSES-MANIFEST.sha256: $extra"
  mv "$t" "$dest"
  rm -rf "$work"
  trap - EXIT
  echo "fetch-toolchain: installed $dest sha256=$got"
}

case "${1:-}" in
  download) [ $# -eq 2 ] || die "usage: $0 download <archive-out>"; cmd_download "$2" ;;
  install)  [ $# -eq 3 ] || die "usage: $0 install <archive> <dest-dir>"; cmd_install "$2" "$3" ;;
  *) die "usage: $0 download <archive-out> | install <archive> <dest-dir>" ;;
esac
