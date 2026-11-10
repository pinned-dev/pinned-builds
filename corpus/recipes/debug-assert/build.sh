# shellcheck shell=bash
. "$PB_LIB"
pb_cmake debug-assert "$PB_SRC/debug-assert" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DDEBUG_ASSERT_BUILD_TEST=OFF
