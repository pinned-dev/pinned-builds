# shellcheck shell=bash
. "$PB_LIB"
pb_cmake spirv-headers "$PB_SRC/spirv-headers" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSPIRV_HEADERS_ENABLE_TESTS=OFF \
  -DSPIRV_HEADERS_ENABLE_EXAMPLES=OFF
