# shellcheck shell=bash
. "$PB_LIB"
pb_cmake dragonbox "$PB_SRC/dragonbox" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTING=OFF
