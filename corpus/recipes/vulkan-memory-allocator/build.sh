# shellcheck shell=bash
. "$PB_LIB"
pb_cmake vulkan-memory-allocator "$PB_SRC/vulkan-memory-allocator" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DVMA_BUILD_SAMPLES=OFF \
  -DVMA_BUILD_DOCUMENTATION=OFF
