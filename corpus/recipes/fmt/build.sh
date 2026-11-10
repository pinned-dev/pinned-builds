# shellcheck shell=bash
. "$PB_LIB"
pb_cmake fmt "$PB_SRC/fmt" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DFMT_TEST=OFF \
  -DFMT_DOC=OFF
