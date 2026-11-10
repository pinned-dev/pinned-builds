# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libconfig "$PB_SRC/libconfig" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTS=OFF
