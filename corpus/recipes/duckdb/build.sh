# shellcheck shell=bash
. "$PB_LIB"
pb_cmake duckdb "$PB_SRC/duckdb" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_UNITTESTS=OFF \
  -DBUILD_SHELL=OFF
