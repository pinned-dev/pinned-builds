# shellcheck shell=bash
. "$PB_LIB"
pb_cmake kissfft "$PB_SRC/kissfft" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DKISSFFT_TEST=OFF \
  -DKISSFFT_TOOLS=OFF
