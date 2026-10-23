#!/usr/bin/env bash
# Prove that the sandbox recipe builds run in (sandbox.sh) has no network and
# cannot write outside its work directory.
#
#   netns-check.sh          positive controls on the host, then the negative
#                           check inside the sandbox; exit 0 only if the host
#                           has what the sandbox must not reach
#   netns-check.sh inside   the negative check alone; sandbox.sh runs it in
#                           the build's own namespaces before every build
#
# Positive controls: https://github.com is reachable; a unix socket listening
# under $HOME and one under /var/tmp accept connections; a probe file under
# $HOME is writable.
#
# The negative check requires: only lo; https and TCP by address fail; no
# docker or containerd socket, the probe sockets refuse connections, and no
# socket at all under /run, /tmp, /var/tmp and $HOME; the probe file, the
# GitHub Actions command files (GITHUB_ENV, GITHUB_PATH, GITHUB_OUTPUT,
# GITHUB_STATE, GITHUB_STEP_SUMMARY, when set) and the scripts directory are
# not writable; no descriptor above 2, and none of 0-2 is a socket.
#
# On ubuntu-24.04 runners unprivileged user namespaces are blocked by AppArmor
# until kernel.apparmor_restrict_unprivileged_userns is set to 0.
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd -P)
PROBE_URL=https://github.com/
SOCKETS="/var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock /var/run/containerd/containerd.sock"

die() { echo "netns-check: FAIL: $*" >&2; exit 1; }

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

inside() {
  local ifaces s f fd n target found
  # /proc/net/dev lists the interfaces of the current network namespace.
  ifaces=$(tail -n +3 /proc/net/dev | cut -d: -f1 | tr -d ' ' | sort | tr '\n' ' ')
  [ "$ifaces" = "lo " ] || die "namespace has interfaces other than lo: $ifaces"
  if curl --silent --max-time 10 -o /dev/null "$PROBE_URL"; then
    die "$PROBE_URL is reachable inside the namespace"
  fi
  if (exec 3<> /dev/tcp/140.82.112.3/443) 2> /dev/null; then
    die "a TCP connection by address succeeded inside the namespace"
  fi
  for s in $SOCKETS ${PB_PROBE_SOCKETS:-}; do
    if [ -e "$s" ] || [ -L "$s" ]; then die "$s is visible inside the namespace"; fi
    if connects "$s"; then die "$s accepts connections inside the namespace"; fi
  done
  found=$(find /run /tmp /var/tmp ${HOME:+"$HOME"} -xdev -type s -print -quit 2> /dev/null || true)
  [ -z "$found" ] || die "unix socket visible inside the namespace: $found"
  for f in ${PB_PROBE_FILE:-} ${GITHUB_ENV:-} ${GITHUB_PATH:-} ${GITHUB_OUTPUT:-} \
           ${GITHUB_STATE:-} ${GITHUB_STEP_SUMMARY:-} "$HERE/.netns-check-write-probe"; do
    if writable "$f"; then die "$f is writable inside the namespace"; fi
  done
  if ! echo 2> /dev/null > /dev/null; then die "/dev/null is not writable inside the namespace"; fi
  for f in ${PB_SANDBOX_RW:-}; do
    writable "$f/.netns-check-rw-probe" || die "the work directory $f is not writable"
    rm -f "$f/.netns-check-rw-probe"
  done
  for fd in "/proc/$$/fd"/*; do
    n=${fd##*/}
    [ -e "$fd" ] || continue # the descriptor the glob itself used, now closed
    target=$(readlink "$fd" || true)
    # bash reads this script through 255 (close-on-exec); that one is fine
    if [ "$n" = 255 ] && [ "$target" = "$(readlink -f "$0")" ]; then continue; fi
    if [ "$n" -gt 2 ]; then die "inherited descriptor $n ($target) inside the namespace"; fi
    case "$target" in socket:*) die "descriptor $n is a socket inside the namespace" ;; esac
  done
  echo "netns-check: inside: interfaces [${ifaces% }], $PROBE_URL unreachable, TCP by address refused," \
       "docker/containerd and probe sockets unreachable, no sockets under /run /tmp /var/tmp \$HOME," \
       "probe file, GitHub command files and scripts read-only, work dirs writable, descriptors 0-2 only, none a socket"
}

# (globals, because the EXIT trap runs after outside() has returned)
h='' v='' pids=()
outside() {
  local s
  curl --silent --show-error --max-time 30 -o /dev/null "$PROBE_URL" ||
    die "positive control: $PROBE_URL is not reachable from the host"
  for s in $SOCKETS; do
    if [ -S "$s" ]; then echo "netns-check: host has $s (must be hidden in the sandbox)"; fi
  done
  if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then die "HOME is not set to a directory"; fi
  h=$(mktemp -d "$HOME/.netns-check.XXXXXX")
  v=$(mktemp -d /var/tmp/.netns-check.XXXXXX)
  cleanup() {
    [ ${#pids[@]} -eq 0 ] || kill "${pids[@]}" 2> /dev/null || true
    if [ -n "$h" ]; then rm -f "$h/s.sock" "$h/probe"; rmdir "$h" 2> /dev/null || true; fi
    if [ -n "$v" ]; then rm -f "$v/s.sock"; rmdir "$v" 2> /dev/null || true; fi
  }
  trap cleanup EXIT
  for s in "$h/s.sock" "$v/s.sock"; do
    python3 -I -c 'import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.listen(8)
time.sleep(120)' "$s" &
    pids+=($!)
  done
  : > "$h/probe"
  for s in "$h/s.sock" "$v/s.sock"; do
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S "$s" ] && break; sleep 0.2; done
    connects "$s" || die "positive control: the probe socket $s does not accept connections"
  done
  writable "$h/probe" || die "positive control: $h/probe is not writable on the host"
  echo "netns-check: host reaches $PROBE_URL and the probe sockets; probe file writable"
  PB_PROBE_SOCKETS="$h/s.sock $v/s.sock" PB_PROBE_FILE="$h/probe" "$HERE/sandbox.sh" -- true ||
    die "the sandbox check did not pass (are unprivileged user namespaces allowed here?)"
  echo "netns-check: PASS"
}

case "${1:-}" in
  inside) inside ;;
  '') outside ;;
  *) die "usage: $0 [inside]" ;;
esac
