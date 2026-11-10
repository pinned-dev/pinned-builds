# shellcheck shell=bash
. "$PB_LIB"
pb_cmake nng "$PB_SRC/nng" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DNNG_ENABLE_TLS=OFF \
  -DNNG_TESTS=OFF \
  -DNNG_TOOLS=OFF
