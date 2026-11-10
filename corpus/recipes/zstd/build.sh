# shellcheck shell=bash
. "$PB_LIB"
pb_cmake zstd "$PB_SRC/zstd/build/cmake" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DZSTD_BUILD_SHARED=OFF
