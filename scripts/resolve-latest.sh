#!/bin/sh
# Resolve the latest stable release of every component the curl build uses,
# and print them as GitHub step outputs (plus a `fingerprint` of all of them).
#
# Components:
#   - the five git submodules (curl, c-ares, nghttp2, nghttp3, ngtcp2):
#     latest GitHub release tag of each upstream repo
#   - BoringSSL: latest 0.YYYYMMDD.N release tag of google/boringssl (built
#     from the submodule by scripts/build-boringssl.sh, with vvb2060's patches)
#   - Android Gradle Plugin: latest stable version on dl.google.com
#   - Gradle wrapper: services.gradle.org/versions/current
#   - JDK: latest LTS from Adoptium
#   - NDK, build-tools, platform, platform-tools: latest stable entries in
#     Google's repository2-*.xml (previews/betas/rcs excluded)
#
# Nothing here is pinned in the repo; run it from the repo root. When
# GITHUB_OUTPUT is not set (local run) the outputs are printed to stdout.
set -eu

out=${GITHUB_OUTPUT:-/dev/stdout}

# POSIX sh has no arrays; wrap curl to add the auth headers.
gh_curl() {
  if [ -n "${GH_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" "$@"
  else
    curl -fsSL "$@"
  fi
}

emit() { printf '%s=%s\n' "$1" "$2" >> "$out"; }

# Latest release tag of an upstream repo. Falls back to the highest version
# tag if the repo has no GitHub releases.
latest_tag() {
  repo=$1
  tag=$(gh_curl "https://api.github.com/repos/$repo/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' || true)
  if [ -z "$tag" ]; then
    tag=$(git ls-remote --tags "https://github.com/$repo.git" \
          | sed 's|.*refs/tags/||; s/\^{}$//' | sort -V | tail -n 1)
  fi
  [ -n "$tag" ] || { echo "cannot resolve latest tag for $repo" >&2; exit 1; }
  printf '%s' "$tag"
}

curl_tag=$(latest_tag curl/curl)
cares_tag=$(latest_tag c-ares/c-ares)
nghttp2_tag=$(latest_tag nghttp2/nghttp2)
nghttp3_tag=$(latest_tag ngtcp2/nghttp3)
ngtcp2_tag=$(latest_tag ngtcp2/ngtcp2)

# BoringSSL publishes date-based release tags (0.YYYYMMDD.N) and no GitHub
# "releases", so take the highest 0.* tag. The ^{} lines are annotated-tag
# dereferences and collapse to the same name after the sed.
boringssl_tag=$(git ls-remote --tags https://github.com/google/boringssl.git 'refs/tags/0.*' \
                | sed 's|.*refs/tags/||; s/\^{}$//' | sort -V | tail -n 1)
[ -n "$boringssl_tag" ] || { echo "cannot resolve latest boringssl tag" >&2; exit 1; }

curl_version=${curl_tag#curl-}
curl_version=$(printf '%s' "$curl_version" | tr '_' '.')

# Latest stable AGP from Google's Maven metadata (<latest> can be an alpha).
agp=$(curl -fsSL "https://dl.google.com/dl/android/maven2/com/android/application/com.android.application.gradle.plugin/maven-metadata.xml" \
      | grep -o '<version>[^<]*</version>' | sed 's/<[^>]*>//g' \
      | grep -viE 'alpha|beta|rc[0-9]|dev' | sort -V | tail -n 1)

gradle_version=$(curl -fsSL "https://services.gradle.org/versions/current" \
                 | sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p')

jdk=$(curl -fsSL "https://api.adoptium.net/v3/info/available_releases" \
      | sed -n 's/.*"most_recent_lts": *\([0-9][0-9]*\).*/\1/p')

# Latest stable Android SDK pieces from Google's repository XML. Emitted by the
# python block below as KEY=value lines; values are validated before eval.
sdk=$(python3 - <<'PY'
import re, urllib.request

def get(u):
    return urllib.request.urlopen(u, timeout=60).read().decode()

data = ''.join(get('https://dl.google.com/android/repository/repository2-%d.xml' % i)
               for i in (1, 2, 3))
blocks = re.findall(r'<remotePackage path="([^"]+)">(.*?)</remotePackage>', data, re.S)

def revision(body):
    m = re.search(r'<revision>(.*?)</revision>', body, re.S)
    if not m:
        return []
    return [int(v) for _, v in re.findall(r'<(major|minor|micro)>(\d+)</', m.group(1))]

def stable(body, path):
    rev = re.search(r'<revision>(.*?)</revision>', body, re.S)
    if rev and '<preview>' in rev.group(1):
        return False
    return not re.search(r'beta|canary|alpha|-rc\d', path, re.I)

def url(body):
    m = re.search(r'<url>([^<]+)</url>', body)
    return m.group(1) if m else ''

ndk, bt, plat, pt = [], [], [], []
for path, body in blocks:
    if not stable(body, path):
        continue
    u = url(body)
    if path.startswith('ndk;'):
        ndk.append((revision(body), path, u))
    elif path.startswith('build-tools;'):
        bt.append((revision(body), path, u))
    elif re.fullmatch(r'platforms;android-\d+', path):
        plat.append((int(path.rsplit('-', 1)[1]), path, u))
    elif path == 'platform-tools':
        pt.append((revision(body), path, u))

def last(entries):
    return sorted(entries)[-1]

ndk_rev, ndk_path, ndk_zip = last(ndk)
bt_rev, bt_path, bt_zip = last(bt)
plat_api, plat_path, plat_zip = last(plat)
pt_rev, pt_path, pt_zip = last(pt)

print('ndk_version=%s' % '.'.join(str(x) for x in ndk_rev))
print('ndk_zip=%s' % ndk_zip)
print('build_tools_version=%s' % '.'.join(str(x) for x in bt_rev))
print('build_tools_zip=%s' % bt_zip)
print('platform=android-%d' % plat_api)
print('platform_api=%d' % plat_api)
print('platform_zip=%s' % plat_zip)
print('platform_tools_zip=%s' % pt_zip)
PY
)

printf '%s\n' "$sdk" | grep -qE '^[a-z_]+=[A-Za-z0-9._-]+$' \
  || { echo "unexpected SDK resolver output:" >&2; printf '%s\n' "$sdk" >&2; exit 1; }
eval "$sdk"

fingerprint="curl=$curl_version c-ares=$cares_tag nghttp2=$nghttp2_tag nghttp3=$nghttp3_tag ngtcp2=$ngtcp2_tag boringssl=$boringssl_tag agp=$agp gradle=$gradle_version jdk=$jdk ndk=$ndk_version build-tools=$build_tools_version platform=$platform"

{
  echo "curl_tag=$curl_tag"
  echo "curl_version=$curl_version"
  echo "cares_tag=$cares_tag"
  echo "nghttp2_tag=$nghttp2_tag"
  echo "nghttp3_tag=$nghttp3_tag"
  echo "ngtcp2_tag=$ngtcp2_tag"
  echo "boringssl_tag=$boringssl_tag"
  echo "agp=$agp"
  echo "gradle_version=$gradle_version"
  echo "jdk=$jdk"
  echo "ndk_version=$ndk_version"
  echo "ndk_zip=$ndk_zip"
  echo "build_tools_version=$build_tools_version"
  echo "build_tools_zip=$build_tools_zip"
  echo "platform=$platform"
  echo "platform_api=$platform_api"
  echo "platform_zip=$platform_zip"
  echo "platform_tools_zip=$platform_tools_zip"
  echo "fingerprint=$fingerprint"
} >> "$out"

echo "resolved latest: $fingerprint"
