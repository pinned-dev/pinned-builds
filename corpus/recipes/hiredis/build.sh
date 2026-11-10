# shellcheck shell=bash
. "$PB_LIB"
pb_cmake hiredis "$PB_SRC/hiredis" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DDISABLE_TESTS=ON \
  -DENABLE_SSL=OFF
