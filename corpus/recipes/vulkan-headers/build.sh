# shellcheck shell=bash
. "$PB_LIB"
pb_cmake vulkan-headers "$PB_SRC/vulkan-headers" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DVULKAN_HEADERS_ENABLE_TESTS=OFF
