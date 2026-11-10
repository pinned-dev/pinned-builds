# shellcheck shell=bash
. "$PB_LIB"
pb_cmake protobuf "$PB_SRC/protobuf/cmake" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dprotobuf_BUILD_TESTS=OFF \
  -Dprotobuf_BUILD_EXAMPLES=OFF \
  -Dprotobuf_WITH_ZLIB=OFF
