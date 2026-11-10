# shellcheck shell=bash
. "$PB_LIB"
pb_cmake hopscotch-map "$PB_SRC/hopscotch-map" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTSL_HOPSCOTCH_MAP_BUILD_TESTS=OFF
