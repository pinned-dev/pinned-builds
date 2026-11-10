# shellcheck shell=bash
. "$PB_LIB"
pb_cmake spirv-cross "$PB_SRC/spirv-cross" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSPIRV_CROSS_ENABLE_TESTS=OFF
