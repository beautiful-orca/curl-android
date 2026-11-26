#!/bin/sh
# Build static BoringSSL (libcrypto.a + libssl.a) from the boringssl submodule
# for every ABI the :tool module builds, and stage the libraries where
# Android.mk expects them. Applies vvb2060's cert-dir patch first, so the
# default CA directory is Android's system store.
#
# Run this before ./gradlew :tool:assembleRelease. The output directory is
# gitignored; it is a build artifact, not a source file.
#
# BoringSSL's CMake build needs Go and Perl on the host; both are preinstalled
# on ubuntu-latest runners.
set -eu

# The workflow passes NDK_VERSION (the image's SDK root ships its own NDK side
# by side); fall back to the only installed NDK for manual runs.
if [ -n "${NDK_VERSION:-}" ]; then
  NDK="${ANDROID_HOME:?set ANDROID_HOME}/ndk/$NDK_VERSION"
else
  NDK=$(ls -d "${ANDROID_HOME:?set ANDROID_HOME}"/ndk/*/ 2>/dev/null | head -n 1 || true)
fi
SRC="curl/src/main/native/boringssl"
OUT="curl/src/main/native/prebuilt"

[ -n "$NDK" ] && [ -d "$NDK" ] || { echo "no NDK installed under $ANDROID_HOME/ndk" >&2; exit 1; }
[ -d "$SRC" ] || { echo "boringssl submodule missing at $SRC" >&2; exit 1; }

# vvb2060's cert_dir.patch (vendored at patches/boringssl-cert-dir.patch),
# re-asserted with sed like patch-config.sh does: upstream has changed the
# spelling of this line before ((void) vs ()), so a literal patch is brittle.
# Idempotent, and fails loudly when upstream moves the line -- a silently
# unpatched tree would verify against the wrong CA store.
target="$SRC/crypto/x509/x509_def.cc"
if grep -q '/system/etc/security/cacerts' "$target"; then
  echo "cert-dir patch already applied"
elif grep -q 'X509_get_default_cert_dir.*return X509_CERT_DIR;' "$target"; then
  sed -i 's|\(X509_get_default_cert_dir[^;]*\)return X509_CERT_DIR;|\1return "/system/etc/security/cacerts";|' "$target"
  grep -q 'X509_get_default_cert_dir.*"/system/etc/security/cacerts"' "$target" \
    || { echo "FAIL: cert-dir patch did not apply" >&2; exit 1; }
  echo "applied vvb2060 cert_dir patch"
else
  echo "FAIL: $target has no X509_get_default_cert_dir/X509_CERT_DIR line to patch" >&2
  exit 1
fi

# All five ABIs, because tool/build.gradle sets abiFilters to all five and
# ndk-build configures every one of them. A missing libssl.a for any ABI
# aborts the whole Gradle build, not just that ABI.
for abi in arm64-v8a armeabi-v7a x86 x86_64 riscv64; do
  case "$abi" in
    riscv64) api=35 ;;   # RISC-V Android starts at API 35
    *)       api=21 ;;
  esac

  echo "== boringssl $abi (android-$api)"

  cmake -S "$SRC" -B "build/bssl-$abi" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$api" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -GNinja

  cmake --build "build/bssl-$abi" --target crypto ssl -j"$(nproc)"

  mkdir -p "$OUT/$abi"
  cp "build/bssl-$abi/libcrypto.a" "$OUT/$abi/libcrypto.a"
  cp "build/bssl-$abi/libssl.a"    "$OUT/$abi/libssl.a"
done

echo "staged:"
ls -l "$OUT"/*/libcrypto.a "$OUT"/*/libssl.a
