# shellcheck shell=bash
. "$PB_LIB"
pb_cmake concurrentqueue "$PB_SRC/concurrentqueue" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
