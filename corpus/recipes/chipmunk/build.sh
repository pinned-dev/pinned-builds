# shellcheck shell=bash
. "$PB_LIB"
pb_cmake chipmunk "$PB_SRC/chipmunk" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_DEMOS=OFF \
  -DINSTALL_DEMOS=OFF
