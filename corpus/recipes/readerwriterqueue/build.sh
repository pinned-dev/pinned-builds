# shellcheck shell=bash
. "$PB_LIB"
pb_cmake readerwriterqueue "$PB_SRC/readerwriterqueue" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
