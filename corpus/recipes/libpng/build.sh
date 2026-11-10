# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libpng "$PB_SRC/libpng" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPNG_TESTS=OFF \
  -DPNG_TOOLS=OFF \
  -DCMAKE_PROJECT_INCLUDE="$PB_RECIPE_DIR/dependency-profile.cmake"
