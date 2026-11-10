# shellcheck shell=bash
. "$PB_LIB"
pb_cmake astc-encoder "$PB_SRC/astc-encoder" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DASTCENC_UNITTEST=OFF
