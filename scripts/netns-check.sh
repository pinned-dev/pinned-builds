#!/usr/bin/env bash
# Prove that the namespace recipe builds run in has no network.
#
#   netns-check.sh          positive control on the host (https://github.com
#                           is reachable, and so is the docker socket if the
#                           host has one), then the negative check inside the
#                           build sandbox (sandbox.sh); exit 0 only if the host
#                           reaches the network and the sandbox does not
#   netns-check.sh inside   the negative check alone; sandbox.sh runs it in
#                           the build's own namespaces before every build
#
# The negative check requires: only lo; https and TCP by address fail; no
# docker or containerd socket and no socket at all under /run and /tmp; no
# descriptor above 2, and none of 0-2 is a socket.
#
# On ubuntu-24.04 runners unprivileged user namespaces are blocked by AppArmor
# until kernel.apparmor_restrict_unprivileged_userns is set to 0.
set -euo pipefail
export LC_ALL=C

PROBE_URL=https://github.com/
SOCKETS="/var/run/docker.sock /run/docker.sock /run/containerd/containerd.sock /var/run/containerd/containerd.sock"

die() { echo "netns-check: FAIL: $*" >&2; exit 1; }

inside() {
  local ifaces
  # /proc/net/dev lists the interfaces of the current network namespace.
  ifaces=$(tail -n +3 /proc/net/dev | cut -d: -f1 | tr -d ' ' | sort | tr '\n' ' ')
  [ "$ifaces" = "lo " ] || die "namespace has interfaces other than lo: $ifaces"
  if curl --silent --max-time 10 -o /dev/null "$PROBE_URL"; then
    die "$PROBE_URL is reachable inside the namespace"
  fi
  if (exec 3<> /dev/tcp/140.82.112.3/443) 2> /dev/null; then
    die "a TCP connection by address succeeded inside the namespace"
  fi
  local s fd n target found
  for s in $SOCKETS; do
    if [ -e "$s" ] || [ -L "$s" ]; then die "$s is visible inside the namespace"; fi
    if curl --silent --max-time 5 --unix-socket "$s" -o /dev/null http://d/_ping; then
      die "$s answers inside the namespace"
    fi
  done
  found=$(find /run /tmp -xdev -type s -print -quit 2> /dev/null || true)
  [ -z "$found" ] || die "unix socket visible inside the namespace: $found"
  for fd in "/proc/$$/fd"/*; do
    n=${fd##*/}
    [ -e "$fd" ] || continue # the descriptor the glob itself used, now closed
    target=$(readlink "$fd" || true)
    # bash reads this script through 255 (close-on-exec); that one is fine
    if [ "$n" = 255 ] && [ "$target" = "$(readlink -f "$0")" ]; then continue; fi
    if [ "$n" -gt 2 ]; then die "inherited descriptor $n ($target) inside the namespace"; fi
    case "$target" in socket:*) die "descriptor $n is a socket inside the namespace" ;; esac
  done
  echo "netns-check: inside namespace: interfaces [${ifaces% }], $PROBE_URL unreachable, TCP by address refused, no docker/containerd socket, no sockets under /run or /tmp, descriptors 0-2 only and none a socket"
}

case "${1:-}" in
  inside) inside ;;
  '')
    curl --silent --show-error --max-time 30 -o /dev/null "$PROBE_URL" ||
      die "positive control: $PROBE_URL is not reachable from the host, so the negative check proves nothing"
    echo "netns-check: host reaches $PROBE_URL"
    for s in $SOCKETS; do
      if [ -S "$s" ]; then echo "netns-check: host has $s (must be hidden in the sandbox)"; fi
    done
    "$(dirname "$0")/sandbox.sh" true ||
      die "the sandbox check did not pass (are unprivileged user namespaces allowed here?)"
    echo "netns-check: PASS"
    ;;
  *) die "usage: $0 [inside]" ;;
esac
