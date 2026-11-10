# shellcheck shell=bash
. "$PB_LIB"
pb_cmake meshoptimizer "$PB_SRC/meshoptimizer" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DMESHOPT_BUILD_DEMO=OFF \
  -DMESHOPT_BUILD_GLTFPACK=OFF
