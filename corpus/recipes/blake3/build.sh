# shellcheck shell=bash
. "$PB_LIB"
pb_cmake blake3 "$PB_SRC/blake3/c" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
