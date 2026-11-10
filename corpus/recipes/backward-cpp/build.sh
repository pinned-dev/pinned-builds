# shellcheck shell=bash
. "$PB_LIB"
pb_cmake backward-cpp "$PB_SRC/backward-cpp" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBACKWARD_TESTS=OFF
