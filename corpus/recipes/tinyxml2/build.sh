# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tinyxml2 "$PB_SRC/tinyxml2" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dtinyxml2_BUILD_TESTING=OFF
