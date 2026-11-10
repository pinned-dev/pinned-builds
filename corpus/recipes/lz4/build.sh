# shellcheck shell=bash
. "$PB_LIB"
pb_cmake lz4 "$PB_SRC/lz4/build/cmake" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLZ4_BUILD_CLI=OFF \
  -DLZ4_BUILD_LEGACY_LZ4C=OFF
