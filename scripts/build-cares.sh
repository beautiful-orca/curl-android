#!/bin/sh
# Build a static c-ares for every ABI the :tool module builds, and stage the
# library plus the generated ares_build.h where Android.mk expects them.
#
# Run this before ./gradlew :tool:assembleRelease. The output directory is
# gitignored; it is a build artifact, not a source file.
set -eu

# The workflow passes NDK_VERSION (the image's SDK root ships its own NDK side
# by side); fall back to the only installed NDK for manual runs.
if [ -n "${NDK_VERSION:-}" ]; then
  NDK="${ANDROID_HOME:?set ANDROID_HOME}/ndk/$NDK_VERSION"
else
  NDK=$(ls -d "${ANDROID_HOME:?set ANDROID_HOME}"/ndk/*/ 2>/dev/null | head -n 1 || true)
fi
SRC="curl/src/main/native/c-ares"
OUT="curl/src/main/native/prebuilt"

[ -n "$NDK" ] && [ -d "$NDK" ] || { echo "no NDK installed under $ANDROID_HOME/ndk" >&2; exit 1; }
[ -d "$SRC" ] || { echo "c-ares submodule missing at $SRC" >&2; exit 1; }

# All five ABIs, because tool/build.gradle sets abiFilters to all five and
# ndk-build configures every one of them. A missing libcares.a for any ABI
# aborts the whole Gradle build, not just that ABI.
for abi in arm64-v8a armeabi-v7a x86 x86_64 riscv64; do
  case "$abi" in
    riscv64) api=35 ;;   # RISC-V Android starts at API 35
    *)       api=21 ;;
  esac

  echo "== c-ares $abi (android-$api)"

  cmake -S "$SRC" -B "build/cares-$abi" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$api" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCARES_STATIC=ON \
    -DCARES_SHARED=OFF \
    -DCARES_STATIC_PIC=ON \
    -DCARES_BUILD_TOOLS=OFF \
    -DCARES_BUILD_TESTS=OFF \
    -DCARES_INSTALL=OFF

  cmake --build "build/cares-$abi" -j"$(nproc)"

  # c-ares writes ares_build.h to the top of the build tree, not to include/.
  # Locate both outputs instead of hardcoding a layout that upstream can change.
  lib=$(find "build/cares-$abi" -name libcares.a -type f | head -n 1)
  hdr=$(find "build/cares-$abi" -name ares_build.h -type f | head -n 1)

  [ -n "$lib" ] || { echo "libcares.a not produced for $abi" >&2; exit 1; }
  [ -n "$hdr" ] || { echo "ares_build.h not produced for $abi" >&2; exit 1; }

  mkdir -p "$OUT/$abi"
  cp "$lib" "$OUT/$abi/libcares.a"
  cp "$hdr" "$OUT/$abi/ares_build.h"
done

echo
echo "== staged"
for abi in arm64-v8a armeabi-v7a x86 x86_64 riscv64; do
  printf '%-12s %9s  %s\n' "$abi" \
    "$(stat -c%s "$OUT/$abi/libcares.a")" \
    "$(ar p "$OUT/$abi/libcares.a" "$(ar t "$OUT/$abi/libcares.a" | head -n 1)" \
       | file - | sed 's/^\/dev\/stdin: ELF //;s/, version.*//')"
done
