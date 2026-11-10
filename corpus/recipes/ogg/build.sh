# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ogg "$PB_SRC/ogg" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTING=OFF
