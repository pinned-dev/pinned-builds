# shellcheck shell=bash
. "$PB_LIB"
pb_cmake opencl-headers "$PB_SRC/opencl-headers" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DOPENCL_HEADERS_BUILD_TESTING=OFF \
  -DOPENCL_HEADERS_BUILD_CXX_TESTS=OFF
