# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libtiff "$PB_SRC/libtiff" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dtiff-tools=OFF \
  -Dtiff-tests=OFF \
  -Dtiff-contrib=OFF \
  -Dtiff-docs=OFF \
  -Djpeg=OFF \
  -Dlzma=OFF \
  -Dzstd=OFF \
  -Dwebp=OFF \
  -Djbig=OFF
