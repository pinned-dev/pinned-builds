# libjpeg-turbo

Native configure/capture of https://github.com/libjpeg-turbo/libjpeg-turbo at `3.1.0`.
Exact source commit/archive SHA-256, options and license notices are in
`corpus/packages.json` and `sources.txt`. Tests and builds are not executed
by this configure-only profile.

Declared feature tags: c, generated-config, compiler-probes.
Tags describe intended samples, not verified semantic coverage.

The profile sets PKGEMAIL to the public upstream issues URL so captured cache
metadata carries a URL rather than an email address. License notices are preserved.
The declared public-metadata.cmake hook uses CMake DEFER to set neutral cache
help for that field at the end of configuration. Upstream's default help embeds
a contact address even after the value is overridden. Original output bytes from
this explicitly configured profile are captured without redaction.
