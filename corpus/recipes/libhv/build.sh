# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libhv "$PB_SRC/libhv" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_EXAMPLES=OFF \
  -DWITH_OPENSSL=OFF
