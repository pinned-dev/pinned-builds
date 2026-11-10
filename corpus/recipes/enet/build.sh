# shellcheck shell=bash
. "$PB_LIB"
pb_cmake enet "$PB_SRC/enet" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
