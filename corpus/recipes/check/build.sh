# shellcheck shell=bash
. "$PB_LIB"
pb_cmake check "$PB_SRC/check" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCHECK_ENABLE_TESTS=OFF
