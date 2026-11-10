# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tl-optional "$PB_SRC/tl-optional" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DOPTIONAL_BUILD_TESTS=OFF
