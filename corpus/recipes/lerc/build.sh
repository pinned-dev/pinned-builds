# shellcheck shell=bash
. "$PB_LIB"
pb_cmake lerc "$PB_SRC/lerc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
