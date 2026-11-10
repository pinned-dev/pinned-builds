# shellcheck shell=bash
. "$PB_LIB"
pb_cmake pugixml "$PB_SRC/pugixml" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPUGIXML_BUILD_TESTS=OFF
