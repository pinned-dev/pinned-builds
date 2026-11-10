# shellcheck shell=bash
. "$PB_LIB"
pb_cmake linenoise-ng "$PB_SRC/linenoise-ng" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
