# shellcheck shell=bash
. "$PB_LIB"
pb_cmake string-view-lite "$PB_SRC/string-view-lite" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSTRING_VIEW_LITE_OPT_BUILD_TESTS=OFF \
  -DSTRING_VIEW_LITE_OPT_BUILD_EXAMPLES=OFF
