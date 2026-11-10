# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libjpeg-turbo "$PB_SRC/libjpeg-turbo" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_SIMD=OFF \
  -DWITH_TURBOJPEG=OFF \
  -DENABLE_SHARED=OFF
