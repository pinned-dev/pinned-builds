# shellcheck shell=bash
. "$PB_LIB"
pb_cmake json-c "$PB_SRC/json-c" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DDISABLE_EXTRA_LIBS=ON
