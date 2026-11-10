# shellcheck shell=bash
. "$PB_LIB"
pb_cmake yyjson "$PB_SRC/yyjson" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DYYJSON_BUILD_TESTS=OFF
