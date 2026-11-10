# shellcheck shell=bash
. "$PB_LIB"
pb_cmake taglib "$PB_SRC/taglib" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_ZLIB=OFF
