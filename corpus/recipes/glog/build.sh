# shellcheck shell=bash
. "$PB_LIB"
pb_cmake glog "$PB_SRC/glog" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWITH_GFLAGS=OFF \
  -DWITH_GTEST=OFF \
  -DWITH_UNWIND=OFF
