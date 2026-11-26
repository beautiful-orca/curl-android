#!/bin/sh
# Materialise the four generated files the build needs but the submodules do not
# carry. Upstream's CI does the same thing in its "Copy version files" step;
# without it ndk-build fails on a missing nghttp2/nghttp2ver.h.
#
# Run this once after cloning, and again after any submodule update.
set -eu

NATIVE=curl/src/main/native

[ -d "$NATIVE/config/versions" ] || { echo "run this from the repo root" >&2; exit 1; }

cp "$NATIVE/config/versions/nghttp2ver.h" "$NATIVE/nghttp2/lib/includes/nghttp2/nghttp2ver.h"
cp "$NATIVE/config/versions/nghttp3ver.h" "$NATIVE/nghttp3/lib/includes/nghttp3/version.h"
cp "$NATIVE/config/versions/ngtcp2ver.h" "$NATIVE/ngtcp2/lib/includes/ngtcp2/version.h"
echo '#include "tool_hugehelp.h"' > "$NATIVE/curl/src/tool_hugehelp.c"

echo "prepared:"
ls -l "$NATIVE/nghttp2/lib/includes/nghttp2/nghttp2ver.h" \
      "$NATIVE/nghttp3/lib/includes/nghttp3/version.h" \
      "$NATIVE/ngtcp2/lib/includes/ngtcp2/version.h" \
      "$NATIVE/curl/src/tool_hugehelp.c"
