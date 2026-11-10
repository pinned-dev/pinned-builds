# shellcheck shell=bash
. "$PB_LIB"
pb_cmake eigen "$PB_SRC/eigen" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DEIGEN_BUILD_DOC=OFF \
  -DEIGEN_BUILD_TESTING=OFF
