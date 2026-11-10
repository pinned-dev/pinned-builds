# shellcheck shell=bash
. "$PB_LIB"
pb_cmake onetbb "$PB_SRC/onetbb" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTBB_TEST=OFF \
  -DTBB_EXAMPLES=OFF \
  -DTBB_STRICT=OFF
