# shellcheck shell=bash
. "$PB_LIB"
pb_cmake portaudio "$PB_SRC/portaudio" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DPA_BUILD_EXAMPLES=OFF \
  -DPA_BUILD_TESTS=OFF \
  -DPA_USE_ALSA=OFF \
  -DPA_USE_JACK=OFF
