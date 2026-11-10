# shellcheck shell=bash
. "$PB_LIB"
pb_cmake zip "$PB_SRC/zip" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_DISABLE_TESTING=ON
