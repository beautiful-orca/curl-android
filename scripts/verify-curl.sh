#!/bin/sh
# Gate: refuse to publish a binary that is not a c-ares build.
#
# Usage: ./scripts/verify-curl.sh <dir>
# Expects <dir>/curl-<abi> for the five ABIs.
set -eu

dir=${1:-dist}
[ -d "$dir" ] || { echo "FAIL: no such directory: $dir" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }

found=0
for f in "$dir"/curl-*; do
  [ -f "$f" ] || fail "no curl-<abi> files in $dir"
  found=$((found + 1))
  abi=${f##*/curl-}

  file "$f" | grep -q 'pie executable' || fail "$f is not a PIE executable"

  # 16 KB alignment is required on the 64-bit ABIs that ship. riscv64 is built
  # only because ndk-build configures every ABI in abiFilters; open_webview has
  # no riscv64 directory, so it is not gated. NDK r29 emits it 4 KB aligned.
  case "$abi" in
    arm64-v8a|x86_64)
      readelf -lW "$f" | awk '/LOAD/{print $NF}' | sort -u | grep -qx '0x4000' \
        || fail "$f is not 16 KB aligned" ;;
  esac

  need=$(readelf -dW "$f" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p' | sort | tr '\n' ' ')
  [ "$need" = "libc.so libdl.so libm.so libz.so " ] \
    || fail "$f NEEDED is '$need', expected only platform libs"

  # c-ares/%s is the format string curl prints the resolver version with, so it
  # is present exactly when c-ares is linked. A literal c-ares/1.34.9 never
  # appears: the version is filled in at runtime by ares_version().
  strings -a "$f" | grep -q 'c-ares/%s' \
    || fail "$f has no c-ares; --dns-servers will not work"

  if strings -a "$f" | grep -q 'threaded resolve'; then
    fail "$f has the threaded resolver compiled in"
  fi

  # BoringSSL must be linked in (it is built from the submodule by
  # scripts/build-boringssl.sh), and the cert-dir patch must have survived:
  # the patched literal is the default CA directory.
  strings -a "$f" | grep -q 'BoringSSL' \
    || fail "$f has no BoringSSL linked; TLS will not work"
  strings -a "$f" | grep -q '/system/etc/security/cacerts' \
    || fail "$f has no /system/etc/security/cacerts; cert-dir patch is missing"

  echo "ok  $f"
done

[ "$found" -eq 5 ] || fail "expected 5 binaries in $dir, found $found"
echo "all $found binaries passed"
