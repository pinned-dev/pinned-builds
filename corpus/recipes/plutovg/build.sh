# shellcheck shell=bash
. "$PB_LIB"
pb_cmake plutovg "$PB_SRC/plutovg" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPLUTOVG_BUILD_EXAMPLES=OFF
