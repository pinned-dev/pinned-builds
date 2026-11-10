# shellcheck shell=bash
. "$PB_LIB"
pb_cmake utf8cpp "$PB_SRC/utf8cpp" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUTF8_TESTS=OFF \
  -DUTF8_SAMPLES=OFF
