# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libcds "$PB_SRC/libcds" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_TESTS=OFF
