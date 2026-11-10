# shellcheck shell=bash
. "$PB_LIB"
pb_cmake websocketpp "$PB_SRC/websocketpp" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTS=OFF
