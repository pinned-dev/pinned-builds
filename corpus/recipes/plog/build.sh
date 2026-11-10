# shellcheck shell=bash
. "$PB_LIB"
pb_cmake plog "$PB_SRC/plog" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPLOG_BUILD_SAMPLES=OFF \
  -DPLOG_BUILD_TESTS=OFF
