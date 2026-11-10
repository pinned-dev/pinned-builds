# shellcheck shell=bash
. "$PB_LIB"
pb_cmake capnproto "$PB_SRC/capnproto" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_OPENSSL=OFF
