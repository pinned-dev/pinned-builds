# shellcheck shell=bash
. "$PB_LIB"
pb_cmake mimalloc "$PB_SRC/mimalloc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DMI_BUILD_TESTS=OFF \
  -DMI_BUILD_OBJECT=ON
