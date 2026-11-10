# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libebur128 "$PB_SRC/libebur128" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_TESTS=OFF
