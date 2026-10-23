# shellcheck shell=bash
# Helpers for recipes/<name>/build.sh. build-recipe.sh runs build.sh under
# `env -i` with only the PB_* variables it documents; build.sh sources this
# file through "$PB_LIB".

# pb_cmake <name> <source-dir> [cmake args...]
#   Configure (Ninja, pinned toolchain) and build into $PB_BUILD/<name>.
pb_cmake() {
  local name=$1 src=$2
  shift 2
  "$PB_CMAKE" -S "$src" -B "$PB_BUILD/$name" -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$PB_NINJA" \
    -DCMAKE_TOOLCHAIN_FILE="$PB_TOOLCHAIN_FILE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PB_INSTALL_PREFIX" \
    -DCMAKE_PREFIX_PATH="$PB_PREFIX" \
    -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
    "$@"
  "$PB_CMAKE" --build "$PB_BUILD/$name" --parallel "$PB_JOBS"
}

# pb_cmake_install <name> <source-dir> [cmake args...]
#   pb_cmake, then install into $PB_PREFIX (part of the recorded outputs).
#   The install prefix is the fixed logical path $PB_INSTALL_PREFIX (staged
#   with DESTDIR), so files that record it, such as .pc files, do not depend
#   on the work directory.
pb_cmake_install() {
  pb_cmake "$@"
  DESTDIR="$PB_OUT/root" "$PB_CMAKE" --install "$PB_BUILD/$1"
}

# pb_exec <program> [args...]
#   Run a built program on the toolchain's own loader and libc, not the host's.
pb_exec() {
  "$PB_LOADER" --library-path "$PB_TOOLCHAIN/sysroot/lib" "$@"
}

# pb_smoke <name> <source-dir> <program> [args...]
#   Build a consumer project against $PB_PREFIX, keep <program> under
#   $PB_OUT/smoke/ (recorded) and run it.
pb_smoke() {
  local name=$1 src=$2 prog=$3
  shift 3
  pb_cmake "smoke-$name" "$src"
  mkdir -p "$PB_OUT/smoke"
  cp "$PB_BUILD/smoke-$name/$prog" "$PB_OUT/smoke/$name"
  pb_exec "$PB_OUT/smoke/$name" "$@"
}
