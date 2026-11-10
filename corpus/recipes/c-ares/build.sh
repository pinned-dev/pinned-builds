# shellcheck shell=bash
. "$PB_LIB"
pb_cmake c-ares "$PB_SRC/c-ares" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCARES_BUILD_TESTS=OFF \
  -DCARES_BUILD_TOOLS=OFF
