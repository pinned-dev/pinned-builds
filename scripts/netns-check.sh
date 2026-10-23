#!/usr/bin/env bash
# Prove that the sandbox recipe builds run in (sandbox.sh) has no network,
# cannot write outside its work directory, and cannot see the runner's
# processes, IPC objects or keyrings.
#
#   netns-check.sh          positive controls on the host, then the negative
#                           check inside the sandbox; exit 0 only if the host
#                           has what the sandbox must not reach
#   netns-check.sh inside   the negative check alone; sandbox.sh runs it in
#                           the build's own namespaces before every build
#   netns-check.sh token N  print the fixed token for sandbox.sh exit status N
#
# Positive controls: https://github.com is reachable; a unix socket listening
# under $HOME and one under /var/tmp accept connections; a probe file under
# $HOME is writable; the environ of the probe socket processes is readable;
# a probe file under /dev/shm exists (when /dev/shm is writable); a probe
# pty opens for writing.
#
# The negative check requires: only lo; https and TCP by address fail; no
# mount is writable except /tmp and the work directories; no docker or
# containerd socket, the probe sockets refuse connections, and no
# socket at all under /run, /tmp, /var/tmp and $HOME; the probe file, the
# GitHub Actions command files (GITHUB_ENV, GITHUB_PATH, GITHUB_OUTPUT,
# GITHUB_STATE, GITHUB_STEP_SUMMARY, when set) and the scripts directory are
# not writable; no descriptor above 2, and none of 0-2 is a socket; every
# capability set is empty and no_new_privs is set; unmounting $HOME,
# remounting / or $HOME read-write, and doing either from a nested user
# namespace all fail; the PID namespace differs from the host's and /proc is
# its own, no host process (this script's, sandbox.sh's and its parent's) is
# visible in /proc and none of their environ can be read; unmounting /proc
# from a nested user namespace fails; the IPC namespace differs from the
# host's and /dev/shm and /dev/mqueue are empty; a seccomp filter is in
# place, keyctl, add_key and request_key are refused with EPERM, and the
# host's session and user keyrings can be neither described nor linked by
# serial number (sandbox.sh checks that the session keyring is a new, empty
# one before the filter makes that impossible); keyctl through x32 is
# refused and through int 0x80 kills the caller; /proc/keys and
# /proc/key-users list nothing; there is no controlling
# terminal, and neither the probe pty, /dev/tty nor any other terminal
# device under /dev opens for writing.
#
# On ubuntu-24.04 runners unprivileged user namespaces are blocked by AppArmor
# until kernel.apparmor_restrict_unprivileged_userns is set to 0.
#
# Diagnosis without logs: every failure has a fixed token. Inside, the token
# becomes the exit code (64 + its index in INSIDE_IDS), which sandbox.sh
# passes on; outside, netns-check.sh maps that code (or sandbox.sh's own
# stage code) back to the token and, when GITHUB_STEP_SUMMARY is set, appends
# exactly one line "netns-check: FAIL <token> (exit <n>)" or
# "netns-check: PASS", after one line with the host's user namespace sysctls
# (integers only). Nothing else (no path, no environment) goes there.
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd -P)
PROBE_URL=https://github.com/
SOCKETS="/var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock /var/run/containerd/containerd.sock"

INSIDE_IDS=(ifaces https tcp socket-visible socket-accepts socket-under-hidden
            writable-outside devnull workdir-not-writable caps no-new-privs
            umount-home remount-root remount-home nested-remount-root
            nested-umount-home inherited-fd fd-socket rw-mount host-info pid-ns
            proc-not-own host-pid-visible host-environ-readable
            nested-umount-proc ipc-ns ipc-visible seccomp keyctl-allowed
            add-key-allowed request-key-allowed host-keyring-reachable ctty
            host-tty-writable x32-allowed i386-allowed proc-keys-visible
            host-dev-visible)
SANDBOX_IDS=([1]=unshare [110]=tmpfs-run [111]=keep-bind [112]=readonly-root
             [113]=hide-tmpfs [114]=bind-back [115]=hidden-readonly
             [116]=workdir-rw [117]=check-not-run [118]=session-keyring
             [119]=keyring-filter [125]=usage)
# Inside, assertion i exits with 64 + i, and sandbox.sh passes 64-109 on:
# 64-108 are the assertions and 109 an unknown token. The codes from 110 on
# are sandbox.sh's own stages, so there may be at most 45 assertions.
if [ $((64 + ${#INSIDE_IDS[@]})) -gt 109 ]; then
  echo "netns-check: too many inside assertions for the exit codes 64-108" >&2
  exit 1
fi

# summary <line>: one sanitized line for the GitHub step summary, if any.
summary() {
  [[ $1 =~ ^(FAIL\ [a-z0-9-]+\ \(exit\ [0-9]+\)|PASS|host\ userns:(\ [a-z_]+=[a-z0-9]+)+)$ ]] || return 0
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f "$GITHUB_STEP_SUMMARY" ] && [ -w "$GITHUB_STEP_SUMMARY" ]; then
    printf 'netns-check: %s\n' "$1" >> "$GITHUB_STEP_SUMMARY" || true
  fi
}

# die <token> <message>: inside, exit with the token's code; outside, also
# name the token in the step summary.
die() {
  local id=$1 i; shift
  echo "netns-check: FAIL [$id]: $*" >&2
  if [ "$MODE" = inside ]; then
    for i in "${!INSIDE_IDS[@]}"; do
      if [ "${INSIDE_IDS[$i]}" = "$id" ]; then exit $((64 + i)); fi
    done
    exit 109
  fi
  summary "FAIL $id (exit ${DIE_RC:-1})"
  exit 1
}

# The host's user namespace settings, as integers (or "absent").
host_userns() {
  local f k v out=''
  for f in /proc/sys/kernel/apparmor_restrict_unprivileged_userns \
           /proc/sys/kernel/unprivileged_userns_clone /proc/sys/user/max_user_namespaces; do
    k=${f##*/}
    v=absent
    if [ -r "$f" ]; then v=$(head -c 20 "$f" 2> /dev/null || true); [[ $v =~ ^[0-9]+$ ]] || v=unreadable; fi
    out+=" $k=$v"
  done
  echo "netns-check: host userns:$out"
  summary "host userns:$out"
}

# connects <socket>: exit 0 if a unix socket at that path accepts a connection
connects() {
  python3 -I -c 'import socket, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(5)
try:
    s.connect(sys.argv[1])
except OSError:
    sys.exit(1)' "$1"
}

writable() { (: >> "$1") 2> /dev/null; }

# starttime_field <n> <pid>: field <n> (3 or more) of a process's stat.
starttime_field() {
  local s n=$1
  read -r s 2> /dev/null < "/proc/$2/stat" || return 1
  s=${s##*) }
  set -- $s
  shift $((n - 3))
  echo "$1"
}
# starttime <pid>: the start time of a process (field 22 of its stat).
starttime() { starttime_field 22 "$1"; }

inside() {
  local ifaces s f fd n p target found
  # /proc/net/dev lists the interfaces of the current network namespace.
  ifaces=$(tail -n +3 /proc/net/dev | cut -d: -f1 | tr -d ' ' | sort | tr '\n' ' ')
  [ "$ifaces" = "lo " ] || die ifaces "namespace has interfaces other than lo: $ifaces"
  if curl --silent --max-time 10 -o /dev/null "$PROBE_URL"; then
    die https "$PROBE_URL is reachable inside the namespace"
  fi
  if (exec 3<> /dev/tcp/140.82.112.3/443) 2> /dev/null; then
    die tcp "a TCP connection by address succeeded inside the namespace"
  fi
  for s in $SOCKETS ${PB_PROBE_SOCKETS:-}; do
    if [ -e "$s" ] || [ -L "$s" ]; then die socket-visible "$s is visible inside the namespace"; fi
    if connects "$s"; then die socket-accepts "$s accepts connections inside the namespace"; fi
  done
  found=$(find /run /tmp /var/tmp ${HOME:+"$HOME"} -xdev -type s -print -quit 2> /dev/null || true)
  [ -z "$found" ] || die socket-under-hidden "unix socket visible inside the namespace: $found"
  # Every mount (shadowed ones included) is read-only, except the scratch
  # /tmp and the work directories.
  found=$(python3 -I -c 'import re, sys
unesc = lambda p: re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), p)
rw = sys.argv[1:]
for line in open("/proc/self/mountinfo"):
    f = line.split()
    mp, opts = unesc(f[4]), f[5].split(",")
    if "rw" in opts and mp != "/tmp" and not any(mp == a or mp.startswith(a.rstrip("/") + "/") for a in rw):
        print(mp)
        break' ${PB_SANDBOX_RW:-}) || die rw-mount "cannot read the mount table"
  [ -z "$found" ] || die rw-mount "a writable mount inside the sandbox: $found"
  for f in ${PB_PROBE_FILE:-} ${GITHUB_ENV:-} ${GITHUB_PATH:-} ${GITHUB_OUTPUT:-} \
           ${GITHUB_STATE:-} ${GITHUB_STEP_SUMMARY:-} "$HERE/.netns-check-write-probe"; do
    if writable "$f"; then die writable-outside "$f is writable inside the namespace"; fi
  done
  if ! echo 2> /dev/null > /dev/null; then die devnull "/dev/null is not writable inside the namespace"; fi
  for f in ${PB_SANDBOX_RW:-}; do
    writable "$f/.netns-check-rw-probe" || die workdir-not-writable "the work directory $f is not writable"
    rm -f "$f/.netns-check-rw-probe"
  done
  # No capabilities and no_new_privs, so nothing above can be undone.
  for f in CapInh CapPrm CapEff CapBnd CapAmb; do
    grep -qxE "$f:[[:space:]]+0+" /proc/self/status || die caps "$f is not empty inside the sandbox"
  done
  grep -qxE 'NoNewPrivs:[[:space:]]+1' /proc/self/status || die no-new-privs "no_new_privs is not set inside the sandbox"
  if umount -l "$HOME" 2> /dev/null; then die umount-home "umount of \$HOME succeeded inside the sandbox"; fi
  if mount -o remount,bind,rw / 2> /dev/null; then die remount-root "a read-write remount of / succeeded inside the sandbox"; fi
  if mount -o remount,bind,rw "$HOME" 2> /dev/null; then die remount-home "a read-write remount of \$HOME succeeded inside the sandbox"; fi
  # A nested user namespace: /proc is read-only, so unshare(1) could not map
  # one, but its creator holds every capability in it until execve, so
  # nested-userns.py makes the calls itself.
  python3 -I "$HERE/nested-userns.py" remount-rw / ||
    die nested-remount-root "a nested user namespace could remount / read-write"
  python3 -I "$HERE/nested-userns.py" umount "$HOME" ||
    die nested-umount-home "a nested user namespace could unmount \$HOME"
  # PID namespace: not the host's, /proc is its own (/proc/self is this
  # shell), and no host process sandbox.sh named is there (same PID and same
  # start time), nor its environ readable.
  [ -n "${PB_HOST_PIDNS:-}" ] && [ -n "${PB_HOST_IPCNS:-}" ] && [ -n "${PB_HOST_KEYRING:-}" ] &&
    [ -n "${PB_HOST_PIDS:-}" ] || die host-info "sandbox.sh passed no host namespaces, keyring or processes"
  [ "$(readlink /proc/self/ns/pid)" != "$PB_HOST_PIDNS" ] || die pid-ns "the sandbox shares the host PID namespace"
  s=''
  read -r s _ < /proc/self/stat 2> /dev/null || true
  [ "$s" = "$$" ] || die proc-not-own "/proc is not the sandbox's own"
  for p in $PB_HOST_PIDS; do
    n=${p%%:*}
    # (a sandbox process may have the same PID, but not the same start time)
    [ "$(starttime "$n" || true)" = "${p#*:}" ] || continue
    if head -c 1 "/proc/$n/environ" > /dev/null 2>&1; then
      die host-environ-readable "the environ of host process $n is readable inside the sandbox"
    fi
    die host-pid-visible "host process $n is visible inside the sandbox"
  done
  python3 -I "$HERE/nested-userns.py" umount /proc ||
    die nested-umount-proc "a nested user namespace could unmount /proc"
  [ "$(readlink /proc/self/ns/ipc)" != "$PB_HOST_IPCNS" ] || die ipc-ns "the sandbox shares the host IPC namespace"
  found=$(find /dev/shm /dev/mqueue -mindepth 1 -print -quit 2> /dev/null || true)
  [ -z "$found" ] || die ipc-visible "a host IPC object is visible inside the sandbox: $found"
  # Keyrings: the filter is there, and the runner's keyrings are out of reach.
  grep -qxE 'Seccomp:[[:space:]]+2' /proc/self/status || die seccomp "no seccomp filter inside the sandbox"
  python3 -I "$HERE/deny-keyrings.py" --check keyctl || die keyctl-allowed "keyctl is not refused inside the sandbox"
  python3 -I "$HERE/deny-keyrings.py" --check add_key || die add-key-allowed "add_key is not refused inside the sandbox"
  python3 -I "$HERE/deny-keyrings.py" --check request_key ||
    die request-key-allowed "request_key is not refused inside the sandbox"
  python3 -I "$HERE/deny-keyrings.py" --check x32 || die x32-allowed "keyctl through x32 is not refused inside the sandbox"
  python3 -I "$HERE/deny-keyrings.py" --check i386 2> /dev/null ||
    die i386-allowed "keyctl through int 0x80 is not killed inside the sandbox"
  for f in /proc/keys /proc/key-users; do
    if [ -e "$f" ] && [ -n "$(head -c 1 "$f" 2> /dev/null)" ]; then
      die proc-keys-visible "$f lists keys inside the sandbox"
    fi
    python3 -I "$HERE/nested-userns.py" umount "$f" ||
      die proc-keys-visible "a nested user namespace could unmount the mask over $f"
  done
  python3 -I "$HERE/nested-userns.py" mount-proc ||
    die proc-keys-visible "a nested user namespace could mount a new /proc"
  [ -n "${PB_HOST_USER_KEYRING:-}" ] || die host-info "sandbox.sh passed no host user keyring"
  for s in $PB_HOST_KEYRING $PB_HOST_USER_KEYRING; do
    [ "$s" != none ] || continue
    for f in describe link; do
      python3 -I "$HERE/deny-keyrings.py" --check "$f" "$s" ||
        die host-keyring-reachable "the host keyring $s can be reached by serial ($f) inside the sandbox"
    done
  done
  # The host's headers and /usr/local are hidden: /usr/include is empty, and
  # under /usr/local there is nothing but the kept directories bound back.
  found=$(python3 -I -c 'import os, sys
keep = [os.path.realpath(k) for k in sys.argv[1:]]
inside = lambda p: any(p == k or p.startswith(k + "/") for k in keep)
above = lambda p: any(k.startswith(p + "/") for k in keep)
for top in ("/usr/include", "/usr/local"):
    for dirpath, dirs, files in os.walk(top):
        dirs[:] = [d for d in dirs if not inside(os.path.join(dirpath, d))]
        for n in files + [d for d in dirs if not above(os.path.join(dirpath, d))]:
            print(os.path.join(dirpath, n))
            sys.exit(0)' ${PB_SANDBOX_KEEP:-}) || die host-dev-visible "cannot scan /usr/include and /usr/local"
  [ -z "$found" ] || die host-dev-visible "a host header or /usr/local file is visible inside the sandbox: $found"
  # Terminals: no controlling terminal (field 7 of stat), and no terminal
  # device (majors 4 and 5, and 136-143 for ptys) opens for writing.
  s=$(starttime_field 7 self) || s=''
  [ "$s" = 0 ] || die ctty "the sandbox has a controlling terminal"
  found=$(python3 -I -c 'import os, stat, sys
paths = sys.argv[1:] + ["/dev/tty"]
for root, dirs, files in os.walk("/dev"):
    paths += [os.path.join(root, f) for f in files]
for p in paths:
    try:
        st = os.stat(p)
    except OSError:
        continue
    if not stat.S_ISCHR(st.st_mode) or os.major(st.st_rdev) not in (4, 5, *range(136, 144)):
        continue
    try:
        os.close(os.open(p, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK))
    except OSError:
        continue
    print(p)
    break' ${PB_PROBE_PTY:-}) || die host-tty-writable "cannot scan the terminal devices"
  [ -z "$found" ] || die host-tty-writable "the terminal $found opens for writing inside the sandbox"
  for fd in "/proc/$$/fd"/*; do
    n=${fd##*/}
    [ -e "$fd" ] || continue # the descriptor the glob itself used, now closed
    target=$(readlink "$fd" || true)
    # bash reads this script through 255 (close-on-exec); that one is fine
    if [ "$n" = 255 ] && [ "$target" = "$(readlink -f "$0")" ]; then continue; fi
    if [ "$n" -gt 2 ]; then die inherited-fd "inherited descriptor $n ($target) inside the namespace"; fi
    case "$target" in socket:*) die fd-socket "descriptor $n is a socket inside the namespace" ;; esac
  done
  echo "netns-check: inside: interfaces [${ifaces% }], $PROBE_URL unreachable, TCP by address refused," \
       "only /tmp and work dirs mounted writable, docker/containerd and probe sockets unreachable, no sockets under /run /tmp /var/tmp \$HOME," \
       "probe file, GitHub command files and scripts read-only, work dirs writable, descriptors 0-2 only, none a socket," \
       "no capabilities, no_new_privs set, umount/remount/nested-namespace escapes refused," \
       "own PID namespace and /proc, no host process visible or its environ readable," \
       "own IPC namespace, /dev/shm and /dev/mqueue empty, keyring system calls refused (x32 and i386 too)," \
       "host keyrings unreachable, /proc/keys and /proc/key-users masked," \
       "no controlling terminal, no terminal device writable, /usr/include and /usr/local hidden"
}

# sandbox_token <exit status of sandbox.sh>: the fixed token that names the
# failed sandbox stage or inside assertion, or sandbox-exit.
sandbox_token() {
  local rc=$1
  if [ "$rc" -ge 64 ] && [ "$rc" -lt $((64 + ${#INSIDE_IDS[@]})) ]; then
    echo "inside-${INSIDE_IDS[$((rc - 64))]}"
  elif [ "$rc" -ge 0 ] && [ "$rc" -le 255 ] && [ -n "${SANDBOX_IDS[$rc]:-}" ]; then
    echo "sandbox-${SANDBOX_IDS[$rc]}"
  else
    echo sandbox-exit
  fi
}

# (globals, because the EXIT trap runs after outside() has returned)
h='' v='' shm='' pids=()
outside() {
  local s rc pty
  host_userns
  curl --silent --show-error --max-time 30 -o /dev/null "$PROBE_URL" ||
    die host-https "positive control: $PROBE_URL is not reachable from the host"
  for s in $SOCKETS; do
    if [ -S "$s" ]; then echo "netns-check: host has $s (must be hidden in the sandbox)"; fi
  done
  if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then die host-home "HOME is not set to a directory"; fi
  h=$(mktemp -d "$HOME/.netns-check.XXXXXX") || die host-home "cannot create a probe directory under \$HOME"
  v=$(mktemp -d /var/tmp/.netns-check.XXXXXX) || die host-var-tmp "cannot create a probe directory under /var/tmp"
  cleanup() {
    [ ${#pids[@]} -eq 0 ] || kill "${pids[@]}" 2> /dev/null || true
    if [ -n "$h" ]; then rm -f "$h/s.sock" "$h/probe" "$h/pty"; rmdir "$h" 2> /dev/null || true; fi
    if [ -n "$v" ]; then rm -f "$v/s.sock"; rmdir "$v" 2> /dev/null || true; fi
    if [ -n "$shm" ]; then rm -f "$shm"; fi
  }
  trap cleanup EXIT
  for s in "$h/s.sock" "$v/s.sock"; do
    PB_NETNS_CHECK_ENVIRON_PROBE=1 python3 -I -c 'import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.listen(8)
time.sleep(120)' "$s" &
    pids+=($!)
  done
  : > "$h/probe"
  for s in "$h/s.sock" "$v/s.sock"; do
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S "$s" ] && break; sleep 0.2; done
    connects "$s" || die host-probe-socket "positive control: the probe socket $s does not accept connections"
  done
  writable "$h/probe" || die host-probe-file "positive control: $h/probe is not writable on the host"
  # The nested user namespace probes work: on the host, / remounts.
  if python3 -I "$HERE/nested-userns.py" remount-rw /; then
    die host-nested-userns "positive control: a nested user namespace cannot remount / on the host"
  fi
  for s in "${pids[@]}"; do
    tr '\0' '\n' < "/proc/$s/environ" | grep -qx PB_NETNS_CHECK_ENVIRON_PROBE=1 ||
      die host-environ "positive control: the environ of probe process $s is not readable on the host"
  done
  # A pty held open by a probe process (its name in $h/pty).
  python3 -I -c 'import os, sys, time
m, s = os.openpty()
with open(sys.argv[1] + ".new", "w") as f:
    f.write(os.ttyname(s) + "\n")
os.rename(sys.argv[1] + ".new", sys.argv[1])
time.sleep(120)' "$h/pty" &
  pids+=($!)
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$h/pty" ] && break; sleep 0.2; done
  pty=$(head -n 1 "$h/pty" 2> /dev/null || true)
  case "$pty" in /dev/pts/[0-9]*) ;; *) die host-pty "positive control: no probe pty" ;; esac
  writable "$pty" || die host-pty "positive control: the probe pty $pty is not writable on the host"
  if [ -d /dev/shm ] && [ -w /dev/shm ]; then
    shm=$(mktemp /dev/shm/.netns-check.XXXXXX) || die host-shm "cannot create a probe file under /dev/shm"
  fi
  echo "netns-check: host reaches $PROBE_URL and the probe sockets; probe file writable; probe process environ readable; probe pty writable"
  rc=0
  PB_PROBE_SOCKETS="$h/s.sock $v/s.sock" PB_PROBE_FILE="$h/probe" PB_PROBE_PIDS="${pids[*]}" PB_PROBE_PTY="$pty" \
    "$HERE/sandbox.sh" -- true || rc=$?
  if [ "$rc" -ne 0 ]; then
    DIE_RC=$rc die "$(sandbox_token "$rc")" "the sandbox check did not pass (sandbox exit $rc)"
  fi
  echo "netns-check: PASS"
  summary PASS
}

MODE=${1:-outside}
case "${1:-}" in
  inside) inside ;;
  '') outside ;;
  # (for build-recipe.sh: print the token of a sandbox.sh exit status)
  token) [[ ${2:-} =~ ^[0-9]{1,3}$ ]] && sandbox_token "$2" || echo sandbox-exit ;;
  *) MODE=outside; die usage "usage: $0 [inside | token <exit status>]" ;;
esac
