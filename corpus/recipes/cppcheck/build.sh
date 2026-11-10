# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cppcheck "$PB_SRC/cppcheck" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_GUI=OFF \
  -DBUILD_TESTS=OFF \
  -DUSE_MATCHCOMPILER=OFF
