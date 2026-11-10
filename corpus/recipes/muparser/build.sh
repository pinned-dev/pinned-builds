# shellcheck shell=bash
. "$PB_LIB"
pb_cmake muparser "$PB_SRC/muparser" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_SAMPLES=OFF \
  -DENABLE_OPENMP=OFF
