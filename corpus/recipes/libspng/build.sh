# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libspng "$PB_SRC/libspng" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_EXAMPLES=OFF \
  -DCMAKE_PROJECT_INCLUDE="$PB_RECIPE_DIR/dependency-profile.cmake"
