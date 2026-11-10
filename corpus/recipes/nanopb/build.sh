# shellcheck shell=bash
. "$PB_LIB"
pb_cmake nanopb "$PB_SRC/nanopb" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -Dnanopb_BUILD_GENERATOR=OFF \
  -Dnanopb_BUILD_RUNTIME=ON
