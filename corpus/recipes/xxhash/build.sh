# shellcheck shell=bash
. "$PB_LIB"
pb_cmake xxhash "$PB_SRC/xxhash/cmake_unofficial" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DXXHASH_BUILD_XXHSUM=OFF
