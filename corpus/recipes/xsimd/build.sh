# shellcheck shell=bash
. "$PB_LIB"
pb_cmake xsimd "$PB_SRC/xsimd" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTS=OFF
