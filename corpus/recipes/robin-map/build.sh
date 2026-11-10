# shellcheck shell=bash
. "$PB_LIB"
pb_cmake robin-map "$PB_SRC/robin-map" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTSL_ROBIN_MAP_BUILD_TESTS=OFF
