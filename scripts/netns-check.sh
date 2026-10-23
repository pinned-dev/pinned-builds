#!/usr/bin/env bash
# Prove that the namespace recipe builds run in has no network.
#
#   netns-check.sh          positive control on the host (https://github.com
#                           is reachable), then the negative check inside a
#                           new user+network namespace; exit 0 only if the
#                           host reaches the network and the namespace does not
#   netns-check.sh inside   the negative check alone (used inside the namespace)
#
# On ubuntu-24.04 runners unprivileged user namespaces are blocked by AppArmor
# until kernel.apparmor_restrict_unprivileged_userns is set to 0.
set -euo pipefail
export LC_ALL=C

PROBE_URL=https://github.com/

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
  echo "netns-check: inside namespace: interfaces [${ifaces% }], $PROBE_URL unreachable, TCP by address refused"
}

case "${1:-}" in
  inside) inside ;;
  '')
    curl --silent --show-error --max-time 30 -o /dev/null "$PROBE_URL" ||
      die "positive control: $PROBE_URL is not reachable from the host, so the negative check proves nothing"
    echo "netns-check: host reaches $PROBE_URL"
    unshare --user --map-root-user --net -- "$0" inside ||
      die "network namespace check did not pass (is unshare -rn allowed here?)"
    echo "netns-check: PASS"
    ;;
  *) die "usage: $0 [inside]" ;;
esac
