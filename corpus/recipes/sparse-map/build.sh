# shellcheck shell=bash
. "$PB_LIB"
pb_cmake sparse-map "$PB_SRC/sparse-map" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTSL_SPARSE_MAP_BUILD_TESTS=OFF
