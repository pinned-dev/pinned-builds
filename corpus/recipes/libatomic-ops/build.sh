# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libatomic-ops "$PB_SRC/libatomic-ops" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Denable_docs=OFF \
  -Denable_tests=OFF
