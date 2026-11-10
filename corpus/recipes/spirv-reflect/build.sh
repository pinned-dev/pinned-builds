# shellcheck shell=bash
. "$PB_LIB"
pb_cmake spirv-reflect "$PB_SRC/spirv-reflect" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSPIRV_REFLECT_BUILD_TESTS=OFF \
  -DSPIRV_REFLECT_EXECUTABLE=OFF
