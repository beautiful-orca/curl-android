#!/bin/sh
# Print the curl version pinned by the submodule as MAJOR.MINOR.PATCH.
#
# curlver.h in a git checkout carries a -DEV suffix (LIBCURL_VERSION is
# "8.18.0-DEV"), so the numeric macros are the only reliable source.
set -eu

h=curl/src/main/native/curl/include/curl/curlver.h
[ -f "$h" ] || { echo "curl submodule not checked out at $h" >&2; exit 1; }

major=$(sed -n 's/^#define LIBCURL_VERSION_MAJOR \([0-9][0-9]*\).*/\1/p' "$h")
minor=$(sed -n 's/^#define LIBCURL_VERSION_MINOR \([0-9][0-9]*\).*/\1/p' "$h")
patch=$(sed -n 's/^#define LIBCURL_VERSION_PATCH \([0-9][0-9]*\).*/\1/p' "$h")

[ -n "$major" ] && [ -n "$minor" ] && [ -n "$patch" ] \
  || { echo "cannot parse version macros in $h" >&2; exit 1; }

echo "$major.$minor.$patch"
