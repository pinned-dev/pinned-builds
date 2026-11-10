# shellcheck shell=bash
. "$PB_LIB"
pb_cmake robin-hood "$PB_SRC/robin-hood" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DRH_STANDALONE_PROJECT=OFF \
  -DRH_BUILD_TESTS=OFF
