# shellcheck shell=bash
. "$PB_LIB"
pb_cmake gperftools "$PB_SRC/gperftools" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
