# shellcheck shell=bash
. "$PB_LIB"
pb_cmake oatpp "$PB_SRC/oatpp" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DOATPP_BUILD_TESTS=OFF
