# shellcheck shell=bash
. "$PB_LIB"
pb_cmake bzip3 "$PB_SRC/bzip3" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBZIP3_BUILD_APPS=OFF
