# shellcheck shell=bash
. "$PB_LIB"
pb_cmake replxx "$PB_SRC/replxx" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DREPLXX_BUILD_EXAMPLES=OFF
