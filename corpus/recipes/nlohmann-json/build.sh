# shellcheck shell=bash
. "$PB_LIB"
pb_cmake nlohmann-json "$PB_SRC/nlohmann-json" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DJSON_BuildTests=OFF
