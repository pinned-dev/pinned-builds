# A small CMake package chain: fmt is installed, spdlog finds it with
# find_package(fmt CONFIG) and is installed, and a consumer finds spdlog
# (and, transitively, fmt) and runs.
. "$PB_LIB"
pb_cmake_install fmt "$PB_SRC/fmt" \
  -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=ON
pb_cmake_install spdlog "$PB_SRC/spdlog" \
  -DSPDLOG_FMT_EXTERNAL=ON -DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_BUILD_TESTS=OFF \
  -DSPDLOG_INSTALL=ON
pb_smoke chain "$PB_RECIPE_DIR/smoke" smoke_chain
