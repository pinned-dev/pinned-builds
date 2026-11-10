# shellcheck shell=bash
. "$PB_LIB"
pb_cmake nanomsg "$PB_SRC/nanomsg" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DNN_ENABLE_DOC=OFF \
  -DNN_TESTS=OFF \
  -DNN_TOOLS=OFF
