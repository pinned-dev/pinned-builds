# shellcheck shell=bash
. "$PB_LIB"
pb_cmake ctre "$PB_SRC/ctre" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCTRE_BUILD_TESTS=OFF
