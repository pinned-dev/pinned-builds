# shellcheck shell=bash
. "$PB_LIB"
pb_cmake scope-lite "$PB_SRC/scope-lite" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSCOPE_LITE_OPT_BUILD_TESTS=OFF
