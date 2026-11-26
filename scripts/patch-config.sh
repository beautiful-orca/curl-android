#!/bin/sh
# Enable c-ares in curl's pre-generated config headers.
#
# Idempotent: running it on an already-patched tree is a no-op. It fails if the
# headers do not contain the lines it expects, which is what happens when
# upstream regenerates them for a new curl version. That failure is the point —
# a silently unpatched header produces a threaded-resolver binary that builds
# fine and then fails on device the first time --dns-servers is used.
set -eu

HEADERS="curl/src/main/native/config32/curl_config.h
curl/src/main/native/config64/curl_config.h"

for f in $HEADERS; do
  [ -f "$f" ] || { echo "FAIL: missing $f" >&2; exit 1; }

  if grep -qx '#define USE_ARES 1' "$f"; then
    :
  elif grep -qx '/\* #undef USE_ARES \*/' "$f"; then
    sed -i 's|^/\* #undef USE_ARES \*/$|#define USE_ARES 1|' "$f"
  else
    echo "FAIL: $f has no USE_ARES line to patch" >&2
    exit 1
  fi

  if grep -qx '/\* #undef USE_THREADS_POSIX \*/' "$f"; then
    :
  elif grep -qx '#define USE_THREADS_POSIX 1' "$f"; then
    sed -i 's|^#define USE_THREADS_POSIX 1$|/* #undef USE_THREADS_POSIX */|' "$f"
  else
    echo "FAIL: $f has no USE_THREADS_POSIX line to patch" >&2
    exit 1
  fi
done

# Assert the end state rather than trusting the edits above.
for f in $HEADERS; do
  grep -qx '#define USE_ARES 1' "$f" \
    || { echo "FAIL: USE_ARES not enabled in $f" >&2; exit 1; }
  grep -qx '/\* #undef USE_THREADS_POSIX \*/' "$f" \
    || { echo "FAIL: USE_THREADS_POSIX still enabled in $f" >&2; exit 1; }
done

echo "config headers patched: USE_ARES on, USE_THREADS_POSIX off"
