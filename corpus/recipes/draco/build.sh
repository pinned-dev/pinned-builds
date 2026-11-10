# shellcheck shell=bash
. "$PB_LIB"
pb_cmake draco "$PB_SRC/draco" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DDRACO_TESTS=OFF \
  -DDRACO_JS_GLUE=OFF
