# shellcheck shell=bash
. "$PB_LIB"
pb_cmake uncrustify "$PB_SRC/uncrustify" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
