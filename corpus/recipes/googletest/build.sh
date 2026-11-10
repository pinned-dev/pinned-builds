# shellcheck shell=bash
. "$PB_LIB"
pb_cmake googletest "$PB_SRC/googletest" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dgtest_build_tests=OFF \
  -Dgmock_build_tests=OFF
