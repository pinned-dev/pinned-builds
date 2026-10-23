#!/usr/bin/env bash
# Run a command with no network:
#
#   sandbox.sh <command> [args...]
#
# - every file descriptor above 2 is closed; stdin is /dev/null, and stdout
#   and stderr reach the command through fresh pipes, so it inherits no
#   socket;
# - the command runs in new user, network and mount namespaces: the only
#   interface is lo, and fresh tmpfs mounts over /run and /tmp hide the
#   filesystem sockets there (docker, containerd, dbus, ...);
# - netns-check.sh inside proves all of that in the same namespaces before
#   the command starts, and the command does not start if it fails.
#
# The command, the work directory and the toolchain must not live under
# /run or /tmp, which are hidden inside.
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd)
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

if [ "${1:-}" = --inside ]; then
  shift
  close_fds
  mount -t tmpfs -o mode=0755,nosuid,nodev sandbox-run /run || die "cannot mount tmpfs over /run"
  mount -t tmpfs -o mode=1777,nosuid,nodev sandbox-tmp /tmp || die "cannot mount tmpfs over /tmp"
  "$HERE/netns-check.sh" inside || die "the build namespace is not isolated"
  exec "$@"
fi

[ $# -ge 1 ] || die "usage: $0 <command> [args...]"
for p in "$HERE" "$PWD" "$@"; do
  case "$p" in /run/*|/tmp/*|/var/run/*) die "path under a hidden directory: $p" ;; esac
done

close_fds
set +e
unshare --user --map-root-user --net --mount --propagation private -- \
  "$HERE/sandbox.sh" --inside "$@" < /dev/null > >(cat) 2> >(cat >&2)
rc=$?
set -e
wait
exit "$rc"
