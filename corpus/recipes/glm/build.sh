# shellcheck shell=bash
. "$PB_LIB"
pb_cmake glm "$PB_SRC/glm" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DGLM_BUILD_TESTS=OFF
