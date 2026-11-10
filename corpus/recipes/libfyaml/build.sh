# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libfyaml "$PB_SRC/libfyaml" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
