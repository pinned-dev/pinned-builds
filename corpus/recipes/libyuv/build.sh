# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libyuv "$PB_SRC/libyuv" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUNIT_TEST=OFF
