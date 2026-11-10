# shellcheck shell=bash
. "$PB_LIB"
pb_cmake simpleini "$PB_RECIPE_DIR/wrapper" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSIMPLEINI_BUILD_TESTS=OFF
