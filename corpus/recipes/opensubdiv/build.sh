# shellcheck shell=bash
. "$PB_LIB"
pb_cmake opensubdiv "$PB_SRC/opensubdiv" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DNO_CUDA=ON \
  -DNO_OPENCL=ON \
  -DNO_OPENGL=ON \
  -DNO_PTEX=ON \
  -DNO_TBB=ON \
  -DNO_OMP=ON \
  -DNO_TESTS=ON \
  -DNO_EXAMPLES=ON \
  -DNO_TUTORIALS=ON \
  -DNO_REGRESSION=ON
