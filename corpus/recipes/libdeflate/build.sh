# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libdeflate "$PB_SRC/libdeflate" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLIBDEFLATE_BUILD_TESTS=OFF \
  -DLIBDEFLATE_BUILD_GZIP=OFF
