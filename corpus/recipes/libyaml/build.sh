# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libyaml "$PB_SRC/libyaml" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DYAML_BUILD_TESTS=OFF
