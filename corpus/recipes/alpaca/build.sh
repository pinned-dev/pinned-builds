# shellcheck shell=bash
. "$PB_LIB"
pb_cmake alpaca "$PB_SRC/alpaca" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DALPACA_BUILD_TESTS=OFF
