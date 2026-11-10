# shellcheck shell=bash
. "$PB_LIB"
pb_cmake imath "$PB_SRC/imath" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DIMATH_BUILD_TESTS=OFF \
  -DPYTHON=OFF
