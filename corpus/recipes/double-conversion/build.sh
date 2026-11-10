# shellcheck shell=bash
. "$PB_LIB"
pb_cmake double-conversion "$PB_SRC/double-conversion" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTING=OFF
