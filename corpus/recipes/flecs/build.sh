# shellcheck shell=bash
. "$PB_LIB"
pb_cmake flecs "$PB_SRC/flecs" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DFLECS_TESTS=OFF
