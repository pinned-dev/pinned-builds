# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tlx "$PB_SRC/tlx" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTLX_BUILD_TESTS=OFF
