# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cglm "$PB_SRC/cglm" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCGLM_BUILD_TESTS=OFF
