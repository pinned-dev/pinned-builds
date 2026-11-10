# shellcheck shell=bash
. "$PB_LIB"
pb_cmake libgit2 "$PB_SRC/libgit2" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUSE_HTTPS=OFF \
  -DUSE_SSH=OFF \
  -DREGEX_BACKEND=builtin \
  -DBUILD_CLI=OFF \
  -DBUILD_TESTS=OFF
