# shellcheck shell=bash
. "$PB_LIB"
pb_cmake re2 "$PB_SRC/re2" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DRE2_BUILD_TESTING=OFF
