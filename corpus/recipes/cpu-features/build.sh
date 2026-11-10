# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cpu-features "$PB_SRC/cpu-features" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
