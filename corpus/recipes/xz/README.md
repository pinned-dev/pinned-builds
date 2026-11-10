# xz

Native configure/capture of https://github.com/tukaani-project/xz at `v5.8.1`.
Exact source commit/archive SHA-256, configure options and license notices are
in `corpus/packages.json` and `sources.txt`. No package target build, install
or test execution is performed in this configure profile. Upstream CMake may
define additional targets or run compiler probes during configure.

Declared sample tags: c, static-or-shared, compression, compiler-probes.
Tags describe intended sample diversity, not proven semantic coverage.

This declared configure hook sets PACKAGE_BUGREPORT in the directory compile
definitions to the public upstream issue tracker. The upstream default embeds a
contact address in compiler commands. License notices stay unchanged; generated
Ninja/File API/compilation database bytes are captured without redaction.
