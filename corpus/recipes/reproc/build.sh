# shellcheck shell=bash
. "$PB_LIB"
pb_cmake reproc "$PB_SRC/reproc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DREPROC_TEST=OFF \
  -DREPROC_EXAMPLES=OFF
