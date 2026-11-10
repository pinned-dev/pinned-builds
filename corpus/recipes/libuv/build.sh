# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libuv "$PB_SRC/libuv" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLIBUV_BUILD_TESTS=OFF \
  -DLIBUV_BUILD_BENCH=OFF
