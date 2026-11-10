# shellcheck shell=bash
. "$PB_LIB"
pb_cmake xtl "$PB_SRC/xtl" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTS=OFF
