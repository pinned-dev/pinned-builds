# shellcheck shell=bash
. "$PB_LIB"
pb_cmake unity "$PB_SRC/unity" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
