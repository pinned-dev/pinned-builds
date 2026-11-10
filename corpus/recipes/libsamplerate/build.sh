# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libsamplerate "$PB_SRC/libsamplerate" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLIBSAMPLERATE_EXAMPLES=OFF
