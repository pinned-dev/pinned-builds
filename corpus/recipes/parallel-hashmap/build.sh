# shellcheck shell=bash
. "$PB_LIB"
pb_cmake parallel-hashmap "$PB_SRC/parallel-hashmap" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPHMAP_BUILD_TESTS=OFF \
  -DPHMAP_BUILD_EXAMPLES=OFF
