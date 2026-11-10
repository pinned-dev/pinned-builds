# shellcheck shell=bash
. "$PB_LIB"
pb_cmake valijson "$PB_SRC/valijson" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dvalijson_BUILD_TESTS=OFF \
  -Dvalijson_BUILD_EXAMPLES=OFF
