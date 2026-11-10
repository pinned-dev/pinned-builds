# shellcheck shell=bash
. "$PB_LIB"
pb_cmake glad "$PB_SRC/glad/cmake" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
