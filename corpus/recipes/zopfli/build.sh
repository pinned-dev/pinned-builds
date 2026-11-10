# shellcheck shell=bash
. "$PB_LIB"
pb_cmake zopfli "$PB_SRC/zopfli" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
