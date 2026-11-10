# shellcheck shell=bash
. "$PB_LIB"
pb_cmake nanobench "$PB_SRC/nanobench" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DNANOBENCH_BUILD_TESTS=OFF
