# shellcheck shell=bash
. "$PB_LIB"
pb_cmake tabulate "$PB_SRC/tabulate" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTABULATE_BUILD_TESTS=OFF \
  -DTABULATE_BUILD_SAMPLES=OFF
