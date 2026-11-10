# shellcheck shell=bash
. "$PB_LIB"
pb_cmake gflags "$PB_SRC/gflags" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DGFLAGS_BUILD_TESTING=OFF
