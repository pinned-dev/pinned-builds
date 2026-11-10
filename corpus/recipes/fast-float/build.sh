# shellcheck shell=bash
. "$PB_LIB"
pb_cmake fast-float "$PB_SRC/fast-float" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DFASTFLOAT_TEST=OFF
