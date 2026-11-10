# shellcheck shell=bash
. "$PB_LIB"
pb_cmake snmalloc "$PB_SRC/snmalloc" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSNMALLOC_BUILD_TESTING=OFF
