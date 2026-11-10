# shellcheck shell=bash
. "$PB_LIB"
pb_cmake iniparser "$PB_SRC/iniparser" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_DOCS=OFF
