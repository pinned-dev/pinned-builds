# shellcheck shell=bash
. "$PB_LIB"
pb_cmake hat-trie "$PB_SRC/hat-trie" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DTSL_HAT_TRIE_BUILD_TESTS=OFF
