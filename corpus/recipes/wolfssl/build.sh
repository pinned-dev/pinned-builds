# shellcheck shell=bash
. "$PB_LIB"
pb_cmake wolfssl "$PB_SRC/wolfssl" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWOLFSSL_EXAMPLES=OFF \
  -DWOLFSSL_CRYPT_TESTS=OFF
