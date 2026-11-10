# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tl-expected "$PB_SRC/tl-expected" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DEXPECTED_BUILD_TESTS=OFF
