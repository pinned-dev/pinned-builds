# shellcheck shell=bash
. "$PB_LIB"
pb_cmake mbedtls "$PB_SRC/mbedtls" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_TESTING=OFF \
  -DENABLE_PROGRAMS=OFF
