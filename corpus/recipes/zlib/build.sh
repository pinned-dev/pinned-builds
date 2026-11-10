# shellcheck shell=bash
. "$PB_LIB"
pb_cmake zlib "$PB_SRC/zlib" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DZLIB_BUILD_EXAMPLES=OFF
