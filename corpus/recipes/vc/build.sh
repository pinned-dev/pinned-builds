# shellcheck shell=bash
. "$PB_LIB"
pb_cmake vc "$PB_SRC/vc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
