# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libaec "$PB_SRC/libaec" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
