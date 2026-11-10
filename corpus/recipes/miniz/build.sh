# shellcheck shell=bash
. "$PB_LIB"
pb_cmake miniz "$PB_SRC/miniz" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_EXAMPLES=OFF
