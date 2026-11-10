# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cwalk "$PB_SRC/cwalk" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
