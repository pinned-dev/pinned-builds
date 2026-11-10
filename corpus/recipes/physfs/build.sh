# shellcheck shell=bash
. "$PB_LIB"
pb_cmake physfs "$PB_SRC/physfs" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPHYSFS_BUILD_TEST=OFF \
  -DPHYSFS_BUILD_DOCS=OFF
