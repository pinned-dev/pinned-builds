# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cpptoml "$PB_SRC/cpptoml" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_TESTS=OFF \
  -DCPPTOML_BUILD_EXAMPLES=OFF
