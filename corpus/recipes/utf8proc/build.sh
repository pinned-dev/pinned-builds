# shellcheck shell=bash
. "$PB_LIB"
pb_cmake utf8proc "$PB_SRC/utf8proc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUTF8PROC_ENABLE_TESTING=OFF
