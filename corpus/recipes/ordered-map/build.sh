# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ordered-map "$PB_SRC/ordered-map" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTSL_ORDERED_MAP_BUILD_TESTS=OFF
