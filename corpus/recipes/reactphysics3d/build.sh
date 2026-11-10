# shellcheck shell=bash
. "$PB_LIB"
pb_cmake reactphysics3d "$PB_SRC/reactphysics3d" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DRP3D_BUILD_TESTS=OFF \
  -DRP3D_BUILD_TESTBED=OFF
