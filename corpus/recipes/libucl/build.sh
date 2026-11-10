# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libucl "$PB_SRC/libucl" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
