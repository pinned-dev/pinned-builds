# shellcheck shell=bash
. "$PB_LIB"
pb_cmake capstone "$PB_SRC/capstone" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCAPSTONE_BUILD_TESTS=OFF \
  -DCAPSTONE_BUILD_CSTOOL=OFF
