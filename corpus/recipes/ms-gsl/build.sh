# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ms-gsl "$PB_SRC/ms-gsl" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DGSL_TEST=OFF
