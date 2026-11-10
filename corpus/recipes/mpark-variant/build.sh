# shellcheck shell=bash
. "$PB_LIB"
pb_cmake mpark-variant "$PB_SRC/mpark-variant" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
