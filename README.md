# curl Android (beautiful-orca fork)

Fork of [vvb2060/curl-android](https://github.com/vvb2060/curl-android) that builds
the standalone `curl` binary shipped in
[open_webview](https://github.com/beautiful-orca/open_webview) (installed as
`common/tools/tools/$ARCH/curl` in the Magisk module).

Everything is built from source submodules — there is no Maven prefab for TLS
anymore:

| component | submodule (latest release tag) | purpose |
|---|---|---|
| curl | `curl/src/main/native/curl` | the tool / libcurl |
| c-ares | `curl/src/main/native/c-ares` | async DNS resolver, enables `--dns-servers` |
| BoringSSL | `curl/src/main/native/boringssl` (`google/boringssl`) | TLS + HTTP/3 crypto |
| nghttp2 | `curl/src/main/native/nghttp2` | HTTP/2 |
| ngtcp2 + nghttp3 | `curl/src/main/native/ngtcp2`, `.../nghttp3` | HTTP/3 |

Behavior notes:

- Resolver is c-ares, not the threaded resolver: the `USE_ARES` patch in
  `config32/64/curl_config.h` is re-asserted by `scripts/patch-config.sh` before
  every build, and `scripts/verify-curl.sh` refuses to publish a binary that is
  not a c-ares build.
- BoringSSL is compiled by `scripts/build-boringssl.sh` with the cert-dir patch
  from `vvb2060/BoringSSL_Android` (vendored under
  `curl/src/main/native/patches/`), so the default CA store is Android's
  `/system/etc/security/cacerts`. `scripts/patch-curl.sh` handles curl ↔
  BoringSSL API drift.
- By default: system CA certificate store, c-ares DNS (`--dns-servers` works).

If you only want to use the curl tool, download a release and extract
`curl-<abi>` — it is the `libcurl.so` from the APK, ready to run.

## Releases

`.github/workflows/build-curl.yml` runs daily (and on manual dispatch with a
`force` option). Nothing is pinned in the repo: `scripts/resolve-latest.sh`
resolves the latest stable release of every component and build tool at run
time (submodule tags, AGP, Gradle wrapper, JDK LTS, NDK / build-tools /
platform from Google's repository XML) into a fingerprint, and the job builds
only when that fingerprint differs from the `components:` line in the latest
release's notes. A build checks the submodules out at their release tags, seds
the resolved versions into the gradle files in the ephemeral runner, builds all
five ABIs (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`, `riscv64`), verifies the
binaries (c-ares and BoringSSL linked, cert-dir string present, NEEDED limited
to platform libs, 16 KB aligned on 64-bit ABIs), and publishes a GitHub release
`v<curl-version>` with the `curl-<abi>` binaries and `SHA256SUMS`. If anything
fails, nothing is published. `open_webview` picks the newest release's
`curl-$ABI` asset automatically.

## Manual build

```sh
git clone --recurse-submodules https://github.com/beautiful-orca/curl-android.git
cd curl-android
./scripts/prepare-sources.sh
./scripts/patch-config.sh
./scripts/patch-curl.sh
./scripts/build-boringssl.sh   # needs an NDK under $ANDROID_HOME/ndk
./scripts/build-cares.sh
./gradlew :tool:assembleRelease
unzip -j tool/build/outputs/apk/release/tool-release.apk 'lib/*/libcurl.so' -d out-extracted
```

## Prefab / Maven integration

To consume libcurl as a prefab dependency in your own Android app, use the
upstream [vvb2060/curl-android](https://github.com/vvb2060/curl-android) Maven
artifacts — this fork builds the standalone binary and no longer depends on the
BoringSSL prefab.

## Version

### 8.23.0
- curl 8.23.0, c-ares 1.34.9, nghttp2 1.71.0, nghttp3 1.19.0, ngtcp2 1.26.0,
  boringssl 0.20261105.0 (built from source)
- NDK r30, AGP 9.5.3, Gradle 9.9.2, JDK 25
- first release from this fork's automated pipeline; from here on the exact
  component versions are listed in each release's notes

<details>

### 8.18.0
- curl 8.18.0
- nghttp2 1.68.0
- nghttp3 1.14.0
- ngtcp2 1.19.0
- boringssl 20251124

### 8.12.0
- curl 8.12.0
- nghttp2 1.64.0
- nghttp3 1.7.0
- ngtcp2 1.10.0
- boringssl 20250114

### 8.10.0
- curl 8.10.0
- nghttp2 1.63.0
- nghttp3 1.5.0
- ngtcp2 1.7.0

### 8.9.1
- curl 8.9.1
- nghttp2 1.62.1
- nghttp3 1.4.0
- ngtcp2 1.6.0
- add LTO version
- add riscv64

### 8.8.0
- curl 8.8.0 with [my patch](https://github.com/curl/curl/pull/13816)
- nghttp2 1.62.1
- nghttp3 1.3.0
- ngtcp2 1.5.0

### 8.6.0
- curl 8.6.0
- nghttp2 1.59.0
- nghttp3 1.1.0
- ngtcp2 1.2.0

### 8.5.0
- curl 8.5.0
- nghttp2 1.58.0
- nghttp3 1.1.0
- ngtcp2 1.1.0

### 8.4.0
- curl 8.4.0
- nghttp2 1.57.0
- nghttp3 0.15.0
- ngtcp2 0.19.1

### 8.3.0
- curl 8.3.0 with [my patch](https://github.com/curl/curl/pull/11874)
- nghttp2 1.56.0
- nghttp3 0.15.0
- ngtcp2 0.19.1

### 8.2.1
- curl 8.2.1
- nghttp2 1.55.1
- nghttp3 0.14.0
- ngtcp2 0.18.0

### 8.1.1
- curl 8.1.1
- nghttp2 1.53.0
- nghttp3 0.11.0
- ngtcp2 0.15.0

### 8.1.0
- curl 8.1.0
- nghttp2 1.53.0
- nghttp3 0.11.0
- ngtcp2 0.15.0

### 8.0.1
- curl 8.0.1
- nghttp2 1.52.0
- nghttp3 0.9.0
- ngtcp2 0.13.1

### 7.88.1
- curl 7.88.1
- nghttp2 1.52.0
- nghttp3 0.9.0
- ngtcp2 0.13.1

### 7.87.0
- curl 7.87.0
- nghttp2 1.51.0
- nghttp3 0.8.0
- ngtcp2 0.11.0

### 7.86.0
- curl 7.86.0
- nghttp2 1.50.0
- nghttp3 0.7.1
- ngtcp2 0.10.0

### 7.85.1
- curl 7.85.0
- nghttp2 1.49.0
- nghttp3 0.7.0
- ngtcp2 0.8.0

### 7.85.0
**aar file upload failed, please use 7.85.1**
- curl 7.85.0
- nghttp2 1.49.0
- nghttp3 0.7.0
- ngtcp2 0.8.0

### 7.84.0
- curl 7.84.0 with [my patch](https://github.com/curl/curl/pull/9056)
- nghttp2 1.48.0
- nghttp3 0.5.0
- ngtcp2 0.6.0

### 7.83.0-h3
- curl 7.83.0 with [my patch](https://github.com/curl/curl/pull/8789)
- nghttp2 1.47.0
- nghttp3 0.4.0
- ngtcp2 0.4.0

### 7.83.0-h2
- curl 7.83.0
- nghttp2 1.47.0

### 7.83.0
- curl 7.83.0

### 7.75.0
- curl 7.75.0

</details>
