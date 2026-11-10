# shellcheck shell=bash
. "$PB_LIB"
pb_cmake argparse "$PB_SRC/argparse" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DARGPARSE_BUILD_TESTS=OFF \
  -DARGPARSE_BUILD_SAMPLES=OFF
