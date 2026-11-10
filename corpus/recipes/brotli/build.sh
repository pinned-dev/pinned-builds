# shellcheck shell=bash
. "$PB_LIB"
pb_cmake brotli "$PB_SRC/brotli" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBROTLI_DISABLE_TESTS=ON
