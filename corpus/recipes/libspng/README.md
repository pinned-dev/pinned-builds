# libspng

Native configure/capture of https://github.com/randy408/libspng at `v0.7.4`.
Exact commit/archive SHA-256, options and license notices are in the catalog
and sources.txt. Package build/install/test execution is excluded from this
profile; upstream may define such targets and run compiler probes at configure.

Declared sample tags: c, image.
These tags are sample diversity, not verified specification coverage.

The declared dependency hook configures the separately pinned zlib-native source
as a real zlibstatic target and resolves ZLIB::ZLIB through an interface
that links that actual source target. Dependency examples/install rules are
disabled in a scoped function; parent install configuration is preserved. No prebuilt
library, host dependency, network fetch or dummy path is used. Both source pins
and notices are retained. Build/install/test remain NOT_RUN.
