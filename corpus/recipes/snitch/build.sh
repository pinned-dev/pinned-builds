# shellcheck shell=bash
. "$PB_LIB"
pb_cmake snitch "$PB_SRC/snitch" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSNITCH_DO_TEST=OFF
