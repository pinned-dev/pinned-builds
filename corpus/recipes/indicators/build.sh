# shellcheck shell=bash
. "$PB_LIB"
pb_cmake indicators "$PB_SRC/indicators" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DINDICATORS_BUILD_TESTS=OFF \
  -DINDICATORS_BUILD_SAMPLES=OFF
