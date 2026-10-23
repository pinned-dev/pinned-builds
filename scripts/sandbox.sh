#!/usr/bin/env bash
# Run a command with no network and a read-only view of the host:
#
#   sandbox.sh [--rw DIR]... [--ro DIR]... -- <command> [args...]
#
# - every file descriptor above 2 is closed; stdin is /dev/null, and stdout
#   and stderr reach the command through fresh pipes, so it inherits no
#   socket;
# - the command runs in new user, network and mount namespaces: the only
#   interface is lo;
# - the whole host filesystem is read-only (recursively); fresh tmpfs mounts
#   over /run, /tmp, /var/tmp and $HOME hide the filesystem sockets there
#   (docker, containerd, dbus, gpg-agent, ...), and the $HOME and /var/tmp
#   ones are read-only too; the --ro and --rw directories are bound back in,
#   and only the --rw directories and the scratch /tmp are writable;
# - all capabilities are dropped (effective, permitted, inheritable, ambient
#   and bounding sets) with no_new_privs, so the command cannot unmount or
#   remount anything (uid 0 inside the user namespace stays, but powerless);
# - netns-check.sh inside proves this in the same namespaces and under the
#   same restrictions before the command starts, and the command does not
#   start if it fails.
#
# The scripts directory is always kept (read-only). No kept directory may
# live under /run, which is hidden first. Needs util-linux 2.39 or later
# (recursive read-only bind mounts).
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd -P)
die() { echo "sandbox: $*" >&2; exit 125; }

# Close every descriptor above 2. The glob is expanded before the loop runs,
# so the descriptor bash used to read /proc/$$/fd is already closed. Bash
# reads this script through descriptor 255, which it marks close-on-exec, so
# that one stays (netns-check.sh inside verifies nothing is left).
close_fds() {
  local fd n
  for fd in "/proc/$$/fd"/*; do
    n=${fd##*/}
    # (exec with a failing redirection would end the script, so skip a
    # descriptor that is already gone, like the one the glob used.)
    if [ "$n" -gt 2 ] && [ "$n" -ne 255 ] && [ -e "$fd" ]; then
      exec {n}>&-
    fi
  done
}

RO=("$HERE") RW=()
INSIDE=0
if [ "${1:-}" = --inside ]; then INSIDE=1; shift; fi
while [ $# -gt 0 ]; do
  case "$1" in
    --rw|--ro)
      [ $# -ge 2 ] || die "$1 needs a directory"
      d=$(realpath -e "$2") || die "no such directory: $2"
      [ -d "$d" ] || die "not a directory: $2"
      case "$d/" in /run/*|/var/run/*|/) die "cannot keep $d in the sandbox" ;; esac
      if [ "$1" = --rw ]; then RW+=("$d"); else RO+=("$d"); fi
      shift 2 ;;
    --) shift; break ;;
    *) die "usage: $0 [--rw DIR]... [--ro DIR]... -- <command> [args...]" ;;
  esac
done
[ $# -ge 1 ] || die "no command"

if [ "$INSIDE" = 1 ]; then
  close_fds
  # 1. Hide /run, then keep a handle on every kept directory under it.
  mount -t tmpfs -o mode=0755,nosuid,nodev sandbox-run /run || die "cannot mount tmpfs over /run"
  mkdir /run/keep
  KEEP=("${RO[@]}" "${RW[@]}")
  for i in "${!KEEP[@]}"; do
    mkdir "/run/keep/$i"
    mount --rbind "${KEEP[$i]}" "/run/keep/$i" || die "cannot bind ${KEEP[$i]}"
  done
  # 2. Everything read-only, recursively (device nodes still work).
  mount -o remount,bind,ro=recursive / || die "cannot make / read-only"
  # 3. Hide the other places where stray sockets live.
  hide=(/tmp /var/tmp)
  if [ -n "${HOME:-}" ] && [ -d "$HOME" ] && [ "$HOME" != / ]; then
    hide+=("$(realpath -e "$HOME")")
  fi
  for h in "${hide[@]}"; do
    mount -t tmpfs -o mode=1777,nosuid,nodev sandbox-hide "$h" || die "cannot mount tmpfs over $h"
  done
  # 4. Bind the kept directories back: read-only ones first, then the
  #    writable ones (which may be nested inside them).
  for i in "${!KEEP[@]}"; do
    p=${KEEP[$i]}
    [ -d "$p" ] || mkdir -p "$p" || die "cannot recreate $p"
    mount --rbind "/run/keep/$i" "$p" || die "cannot bind back $p"
  done
  # Nothing may write into the hidden $HOME and /var/tmp either (so a write
  # to, say, a GitHub Actions command file under $HOME fails rather than
  # landing in the tmpfs); /tmp stays a writable scratch tmpfs.
  for h in "${hide[@]:1}"; do
    mount -o remount,bind,ro "$h" || die "cannot make $h read-only"
  done
  for p in "${RW[@]}"; do
    mount -o remount,bind,rw=recursive "$p" || die "cannot make $p writable"
  done
  # 5. Drop every capability for good (the mounts above are only as strong
  #    as the build's inability to undo them), with no_new_privs, and run the
  #    check under exactly the same restrictions as the command.
  CONFINE=(setpriv --no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all --)
  PB_SANDBOX_RW="${RW[*]}" "${CONFINE[@]}" "$HERE/netns-check.sh" inside ||
    die "the build sandbox is not isolated"
  exec "${CONFINE[@]}" "$@"
fi

ARGS=()
for d in "${RO[@]:1}"; do ARGS+=(--ro "$d"); done
for d in "${RW[@]}"; do ARGS+=(--rw "$d"); done
close_fds
set +e
unshare --user --map-root-user --net --mount --propagation private -- \
  "$HERE/sandbox.sh" --inside "${ARGS[@]}" -- "$@" < /dev/null > >(cat) 2> >(cat >&2)
rc=$?
set -e
wait
exit "$rc"
