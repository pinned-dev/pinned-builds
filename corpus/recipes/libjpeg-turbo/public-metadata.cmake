# The upstream cache help embeds a default contact address even when PKGEMAIL
# is overridden. Keep this profile's metadata on the declared public issues URL.
# This is a recorded configure hook; captured output bytes are never redacted.
cmake_language(DEFER CALL set_property CACHE PKGEMAIL PROPERTY HELPSTRING
  "Public upstream issues URL used in package descriptions.")
