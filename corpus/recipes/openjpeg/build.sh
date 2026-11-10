# shellcheck shell=bash
. "$PB_LIB"
pb_cmake openjpeg "$PB_SRC/openjpeg" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_CODEC=OFF
