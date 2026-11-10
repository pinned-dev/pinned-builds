# shellcheck shell=bash
. "$PB_LIB"
pb_cmake parson "$PB_SRC/parson" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
