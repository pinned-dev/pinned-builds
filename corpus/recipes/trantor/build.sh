# shellcheck shell=bash
. "$PB_LIB"
pb_cmake trantor "$PB_SRC/trantor" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
