# shellcheck shell=bash source-path=SCRIPTDIR/../..
# Catch2 3.6.0: build and install the static libraries, then build and run a
# small test program against the installed CMake package.
# shellcheck source=scripts/recipe-lib.sh
. "$PB_LIB"
pb_cmake_install catch2 "$PB_SRC/catch2" \
  -DBUILD_TESTING=OFF -DCATCH_INSTALL_DOCS=OFF -DCATCH_INSTALL_EXTRAS=ON
pb_smoke catch2 "$PB_RECIPE_DIR/smoke" smoke_test --order decl
