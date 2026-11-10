# shellcheck shell=bash
. "$PB_LIB"
pb_cmake quickjs-ng "$PB_SRC/quickjs-ng" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DQJS_BUILD_EXAMPLES=OFF
