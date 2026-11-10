# shellcheck shell=bash
. "$PB_LIB"
pb_cmake openal-soft "$PB_SRC/openal-soft" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DALSOFT_TESTS=OFF \
  -DALSOFT_UTILS=OFF \
  -DALSOFT_EXAMPLES=OFF \
  -DALSOFT_CONFIG=OFF
