# shellcheck shell=bash
. "$PB_LIB"
pb_cmake graphite2 "$PB_SRC/graphite2" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DGRAPHITE2_NFILEFACE=ON
