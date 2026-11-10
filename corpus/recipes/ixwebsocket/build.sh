# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ixwebsocket "$PB_SRC/ixwebsocket" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUSE_TLS=OFF \
  -DUSE_ZLIB=OFF
