# shellcheck shell=bash
. "$PB_LIB"
pb_cmake cjson "$PB_SRC/cjson" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_CJSON_TEST=OFF \
  -DENABLE_CJSON_UTILS=ON
