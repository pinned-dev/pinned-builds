# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ade "$PB_SRC/ade" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
