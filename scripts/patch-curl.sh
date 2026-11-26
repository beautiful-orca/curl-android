#!/bin/sh
# Patch curl's OpenSSL compatibility shims for the BoringSSL we build from
# source. Idempotent; fails loudly when upstream restructures the file.
#
# curl <= 8.23 guards its static ASN1_STRING_get_length shim with
# OPENSSL_VERSION_NUMBER only, but BoringSSL keeps that macro low (0x1010107f)
# while recent releases export the real ASN1_STRING_get_length -> "static
# declaration follows non-static declaration". curl master fixed this by
# renaming the shim to ossl_ASN1_STRING_get_length; until a release carries
# that, disable the shim for BoringSSL when BoringSSL provides the function.
set -eu

CURL_VTLS="curl/src/main/native/curl/lib/vtls/openssl.c"
BSSL_ASN1="curl/src/main/native/boringssl/include/openssl/asn1.h"

[ -f "$CURL_VTLS" ] || { echo "FAIL: missing $CURL_VTLS" >&2; exit 1; }

if grep -q 'ossl_ASN1_STRING_get_length' "$CURL_VTLS"; then
  echo "curl already uses ossl_ASN1_STRING_get_length; nothing to patch"
  exit 0
fi

if ! grep -q 'static size_t ASN1_STRING_get_length' "$CURL_VTLS"; then
  # No shim (e.g. curl 8.18 used ASN1_STRING_length directly): no conflict
  # with BoringSSL possible, nothing to do.
  echo "curl has no ASN1_STRING_get_length shim; nothing to patch"
  exit 0
fi

if grep -q '!defined(OPENSSL_IS_BORINGSSL)' "$CURL_VTLS"; then
  echo "shim already disabled for BoringSSL"
elif grep -q 'ASN1_STRING_get_length' "$BSSL_ASN1"; then
  sed -i 's|^#if OPENSSL_VERSION_NUMBER < 0x40100000L$|#if OPENSSL_VERSION_NUMBER < 0x40100000L \&\& !defined(OPENSSL_IS_BORINGSSL)|' "$CURL_VTLS"
  grep -q '!defined(OPENSSL_IS_BORINGSSL)' "$CURL_VTLS" \
    || { echo "FAIL: could not disable the shim" >&2; exit 1; }
  echo "disabled curl's ASN1_STRING_get_length shim for BoringSSL"
else
  echo "BoringSSL does not export ASN1_STRING_get_length; keeping curl's shim"
fi
