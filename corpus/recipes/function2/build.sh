# shellcheck shell=bash
. "$PB_LIB"
pb_cmake function2 "$PB_SRC/function2" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTING=OFF
