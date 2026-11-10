# shellcheck shell=bash
. "$PB_LIB"
pb_cmake aws-c-common "$PB_SRC/aws-c-common" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
