# shellcheck shell=bash
. "$PB_LIB"
pb_cmake spdlog "$PB_SRC/spdlog" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSPDLOG_BUILD_TESTS=OFF \
  -DSPDLOG_BUILD_EXAMPLE=OFF
