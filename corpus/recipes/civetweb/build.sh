# shellcheck shell=bash
. "$PB_LIB"
pb_cmake civetweb "$PB_SRC/civetweb" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCIVETWEB_ENABLE_SSL=OFF \
  -DCIVETWEB_BUILD_TESTING=OFF
