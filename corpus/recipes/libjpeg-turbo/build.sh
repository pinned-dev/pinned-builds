# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libjpeg-turbo "$PB_SRC/libjpeg-turbo" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_SIMD=OFF \
  -DWITH_TURBOJPEG=OFF \
  -DENABLE_SHARED=OFF \
  -DPKGEMAIL=https://github.com/libjpeg-turbo/libjpeg-turbo/issues \
  -DCMAKE_PROJECT_INCLUDE="$PB_RECIPE_DIR/public-metadata.cmake"
