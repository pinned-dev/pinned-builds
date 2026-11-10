# shellcheck shell=bash
. "$PB_LIB"
pb_cmake asmjit "$PB_SRC/asmjit" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DASMJIT_TEST=OFF
