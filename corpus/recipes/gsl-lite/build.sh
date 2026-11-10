# shellcheck shell=bash
. "$PB_LIB"
pb_cmake gsl-lite "$PB_SRC/gsl-lite" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DGSL_LITE_OPT_BUILD_TESTS=OFF
