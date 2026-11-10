# shellcheck shell=bash
. "$PB_LIB"
pb_cmake antlr4-runtime "$PB_SRC/antlr4-runtime/runtime/Cpp" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DANTLR_BUILD_CPP_TESTS=OFF \
  -DANTLR_BUILD_SHARED=OFF
