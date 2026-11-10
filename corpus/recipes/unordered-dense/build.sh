# shellcheck shell=bash
. "$PB_LIB"
pb_cmake unordered-dense "$PB_SRC/unordered-dense" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DANKERL_UNORDERED_DENSE_BUILD_TESTS=OFF
