# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cpp-peglib "$PB_SRC/cpp-peglib" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTS=OFF \
  -DPEGLIB_BUILD_EXAMPLES=OFF
