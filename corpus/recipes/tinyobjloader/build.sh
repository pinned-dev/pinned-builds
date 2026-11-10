# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tinyobjloader "$PB_SRC/tinyobjloader" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTINYOBJLOADER_BUILD_TEST_LOADER=OFF
