#!/usr/bin/env bash
# Run a command with no network and a read-only view of the host:
#
#   sandbox.sh [--rw DIR]... [--ro DIR]... -- <command> [args...]
#
# - every file descriptor above 2 is closed; stdin is /dev/null, and stdout
#   and stderr reach the command through fresh pipes, so it inherits no
#   socket;
# - the command runs in new user, network, mount, PID and IPC namespaces:
#   the only interface is lo, a fresh /proc shows only the sandbox's own
#   processes (so no runner process can be seen, read or signalled), and
#   SysV IPC and POSIX message queues are the sandbox's own;
# - the command has a new, empty session keyring (scripts/session-keyring.py;
#   the sandbox does not start without one), and a seccomp filter refuses
#   keyctl, add_key and request_key (scripts/deny-keyrings.py), because
#   keyring access is checked by kernel uid, which the sandbox shares with
#   the runner;
# - the whole host filesystem is read-only (recursively); fresh tmpfs mounts
#   over /run, /tmp, /var/tmp and $HOME hide the filesystem sockets there
#   (docker, containerd, dbus, gpg-agent, ...), fresh tmpfs mounts over
#   /dev/shm and /dev/mqueue hide the host's POSIX shared memory and message
#   queues, one over /dev/pts hides the host's ptys (a read-only mount does
#   not stop a device node from being opened for writing), ones over
#   /usr/include and /usr/local hide the host's headers and locally
#   installed tools and libraries (so no build step can copy them into the
#   work directory), and all of them but /tmp are read-only too; the --ro
#   and --rw directories are bound back in, and only the --rw directories
#   and the scratch /tmp are writable;
# - all capabilities are dropped (effective, permitted, inheritable, ambient
#   and bounding sets) with no_new_privs, so the command cannot unmount or
#   remount anything (uid 0 inside the user namespace stays, but powerless);
# - the command runs in a new session with no controlling terminal, so it
#   cannot reach the terminal it was started from through /dev/tty;
# - netns-check.sh inside proves this in the same namespaces and under the
#   same restrictions before the command starts, and the command does not
#   start if it fails.
#
# The scripts directory is always kept (read-only). No kept directory may
# live under /run, which is hidden first. Needs Linux 5.12 or later and
# python3: the recursive read-only and writable remounts call mount_setattr(2)
# through mount-setattr.py, because mount(8) from util-linux 2.39.3
# (ubuntu-24.04) silently ignores "ro=recursive" and remounts / alone.
#
# Exit status: the command's own, or, when the sandbox itself fails, one
# fixed code per stage, so that netns-check.sh can name the stage without
# any log:
#   1        unshare failed (no user, network, mount, PID or IPC namespace,
#            the mount propagation change or the /proc mount was refused,
#            as under an AppArmor unprivileged_userns profile)
#   64-109   an assertion of netns-check.sh inside failed (its own code)
#   110      tmpfs over /run
#   111      keep the kept directories, or mask /proc/keys, /proc/key-users
#   112      make / read-only
#   113      tmpfs over /tmp, /var/tmp, $HOME, /dev/shm, /dev/mqueue,
#            /dev/pts
#   114      bind the kept directories back
#   115      make the hidden $HOME, /var/tmp, ... read-only
#   116      make the --rw directories writable
#   117      netns-check.sh inside did not run (e.g. setpriv failed)
#   118      no new session keyring
#   119      the keyring system call filter could not be installed
#   125      usage
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd -P)
# die <exit code> <message>
die() { local rc=$1; shift; echo "sandbox: $*" >&2; exit "$rc"; }

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
      [ $# -ge 2 ] || die 125 "$1 needs a directory"
      d=$(realpath -e "$2") || die 125 "no such directory: $2"
      [ -d "$d" ] || die 125 "not a directory: $2"
      case "$d/" in /run/*|/var/run/*|/) die 125 "cannot keep $d in the sandbox" ;; esac
      if [ "$1" = --rw ]; then RW+=("$d"); else RO+=("$d"); fi
      shift 2 ;;
    --) shift; break ;;
    *) die 125 "usage: $0 [--rw DIR]... [--ro DIR]... -- <command> [args...]" ;;
  esac
done
[ $# -ge 1 ] || die 125 "no command"

if [ "$INSIDE" = 1 ]; then
  close_fds
  # 1. Hide /run, then keep a handle on every kept directory under it.
  mount -t tmpfs -o mode=0755,nosuid,nodev sandbox-run /run || die 110 "cannot mount tmpfs over /run"
  mkdir /run/keep || die 111 "cannot create /run/keep"
  KEEP=("${RO[@]}" "${RW[@]}")
  for i in "${!KEEP[@]}"; do
    mkdir "/run/keep/$i" || die 111 "cannot create /run/keep/$i"
    mount --rbind "${KEEP[$i]}" "/run/keep/$i" || die 111 "cannot bind ${KEEP[$i]}"
  done
  # 1b. Mask /proc/keys and /proc/key-users: the build's kernel uid is the
  #     runner's, so they would list the runner's keys and keyrings (type,
  #     description, serial, payload length). With them masked, this /proc is
  #     no longer fully visible, so the kernel refuses a new proc mount in a
  #     nested user namespace too.
  for f in /proc/keys /proc/key-users; do
    if [ -e "$f" ]; then mount --bind /dev/null "$f" || die 111 "cannot mask $f"; fi
  done
  # 2. Everything read-only, recursively (device nodes still work).
  python3 -I "$HERE/mount-setattr.py" ro / || die 112 "cannot make / read-only"
  # 3. Hide the other places where stray sockets live.
  hide=(/tmp /var/tmp)
  if [ -n "${HOME:-}" ] && [ -d "$HOME" ] && [ "$HOME" != / ]; then
    home=$(realpath -e "$HOME") || die 113 "cannot resolve \$HOME"
    hide+=("$home")
  fi
  # The host's POSIX shared memory and message queues (the new IPC namespace
  # covers SysV IPC and mq_open(3), but these are plain mounts), and the
  # host's ptys (with them hidden, /dev/ptmx cannot make new ones either).
  for h in /dev/shm /dev/mqueue /dev/pts; do
    if [ -d "$h" ]; then hide+=("$h"); fi
  done
  # The host's headers and everything installed under /usr/local: the
  # toolchain brings its own headers, and nothing the sandbox itself runs
  # lives there (PATH is set to /usr/bin:/bin:/usr/sbin:/sbin below).
  # (The lib*.so development symlinks in /usr/lib* stay: a mount cannot
  # cover a symlink without covering its target, the runtime library that
  # the host tools in the sandbox load, and that runtime library could be
  # copied just the same. The input check after the build is the guard
  # there: the linker records every library it reads.)
  for h in /usr/include /usr/local; do
    if [ -d "$h" ] && [ ! -L "$h" ]; then hide+=("$h"); fi
  done
  for h in "${hide[@]}"; do
    mount -t tmpfs -o mode=1777,nosuid,nodev sandbox-hide "$h" || die 113 "cannot mount tmpfs over $h"
  done
  # 4. Bind the kept directories back: read-only ones first, then the
  #    writable ones (which may be nested inside them).
  for i in "${!KEEP[@]}"; do
    p=${KEEP[$i]}
    [ -d "$p" ] || mkdir -p "$p" || die 114 "cannot recreate $p"
    mount --rbind "/run/keep/$i" "$p" || die 114 "cannot bind back $p"
  done
  # Nothing may write into the hidden $HOME, /var/tmp, /dev/shm, /dev/mqueue
  # and /dev/pts either (so a write to, say, a GitHub Actions command file
  # under $HOME fails rather than landing in the tmpfs); /tmp stays a
  # writable scratch tmpfs.
  for h in "${hide[@]:1}"; do
    mount -o remount,bind,ro "$h" || die 115 "cannot make $h read-only"
  done
  for p in "${RW[@]}"; do
    python3 -I "$HERE/mount-setattr.py" rw "$p" || die 116 "cannot make $p writable"
  done
  # 5. Drop every capability for good (the mounts above are only as strong
  #    as the build's inability to undo them), with no_new_privs, and run the
  #    check under exactly the same restrictions as the command.
  #    The session keyring must still be the new, empty one (from here on
  #    the keyring system calls are refused, so this is the last look).
  ks='' kn=''
  read -r ks kn _ < <(python3 -I "$HERE/session-keyring.py" --show) || true
  [ -n "$ks" ] && [ "$ks" != "${PB_HOST_KEYRING:-}" ] && [ "$kn" = 0 ] ||
    die 118 "the session keyring is not a new, empty one"
  #    setsid: a new session, with no controlling terminal.
  CONFINE=(setpriv --no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all --
           setsid --wait -- python3 -I "$HERE/deny-keyrings.py" 119)
  # A failed assertion keeps its own code (64-109), and a filter that could
  # not be installed its own (119); anything else is 117.
  rc=0
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  PB_SANDBOX_RW="${RW[*]}" PB_SANDBOX_KEEP="${KEEP[*]}" "${CONFINE[@]}" "$HERE/netns-check.sh" inside || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -ge 64 ] && [ "$rc" -le 109 ] || [ "$rc" = 119 ] || rc=117
    die "$rc" "the build sandbox is not isolated"
  fi
  unset PB_HOST_PIDNS PB_HOST_IPCNS PB_HOST_KEYRING PB_HOST_USER_KEYRING PB_HOST_PIDS
  # The command becomes PID 1 of the sandbox: when it exits, the kernel
  # kills whatever it left behind.
  exec "${CONFINE[@]}" "$@"
fi

# starttime <pid>: the start time of a process (field 22 of its stat), which
# with the PID names it uniquely.
starttime() {
  local s
  read -r s < "/proc/$1/stat" || return 1
  s=${s##*) }
  set -- $s
  echo "${20}"
}

ARGS=()
for d in "${RO[@]:1}"; do ARGS+=(--ro "$d"); done
for d in "${RW[@]}"; do ARGS+=(--rw "$d"); done
# What netns-check.sh inside compares against: the host's PID and IPC
# namespaces and session keyring, and host processes (this one, its parent
# and any probe processes) that must not be visible inside.
PB_HOST_PIDNS=$(readlink /proc/self/ns/pid) || die 125 "cannot read the PID namespace"
PB_HOST_IPCNS=$(readlink /proc/self/ns/ipc) || die 125 "cannot read the IPC namespace"
PB_HOST_KEYRING=none PB_HOST_USER_KEYRING=none
read -r PB_HOST_KEYRING _ PB_HOST_USER_KEYRING < <(python3 -I "$HERE/session-keyring.py" --show) || true
PB_HOST_PIDS=''
for p in $$ $PPID ${PB_PROBE_PIDS:-}; do
  t=$(starttime "$p") || die 125 "no such process: $p"
  PB_HOST_PIDS+="$p:$t "
done
export PB_HOST_PIDNS PB_HOST_IPCNS PB_HOST_KEYRING PB_HOST_USER_KEYRING PB_HOST_PIDS
close_fds
set +e
# --kill-child: if unshare is killed, so is the whole sandbox. The new
# session keyring is joined before sandbox.sh --inside starts.
#
# The command is PID 1 of its namespace and in a session of its own, so
# SIGINT, SIGTERM and SIGHUP sent to this process (or its process group)
# would not reach it; they kill the whole sandbox instead. unshare runs in
# the background for that, with SIGINT and SIGQUIT back to their defaults.
( trap - INT QUIT
  exec unshare --user --map-root-user --net --mount --propagation private \
    --pid --fork --kill-child --mount-proc --ipc -- \
    python3 -I "$HERE/session-keyring.py" 118 "$HERE/sandbox.sh" --inside "${ARGS[@]}" -- "$@" ) \
  < /dev/null > >(cat) 2> >(cat >&2) &
child=$!
trap 'kill -KILL "$child" 2> /dev/null' INT TERM HUP
while :; do
  wait "$child"
  rc=$?
  kill -0 "$child" 2> /dev/null || break # (a trapped signal ended the wait)
done
trap - INT TERM HUP
set -e
wait
exit "$rc"
