# shellcheck shell=bash
. "$PB_LIB"
pb_cmake docopt "$PB_SRC/docopt" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_TESTS=OFF
