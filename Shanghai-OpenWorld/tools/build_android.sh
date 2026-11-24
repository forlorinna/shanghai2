#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
sdk="${ANDROID_SDK_ROOT:-$root/tools/android-sdk}"
java_home="${JAVA_HOME:-$root/tools/local/jdk17}"
export JAVA_HOME="$java_home"
export PATH="$java_home/bin:$PATH"
buildtools="${ANDROID_BUILD_TOOLS:-$sdk/build-tools/36.0.0}"
signing="${SHANGHAI_SIGNING_DIR:-$root/tools/signing}"
output="${1:-$root/builds/android/Shanghai-OpenWorld-v0.1.0-arm64.apk}"
out_dir="$(dirname "$output")"
mkdir -p "$out_dir"
output="$(cd "$out_dir" && pwd)/$(basename "$output")"
for utility in "$buildtools/apksigner" "$buildtools/aapt" "$java_home/bin/keytool"; do
    if [[ ! -x "$utility" ]]; then
        printf 'Missing Android build dependency %s\n' "$utility" >&2
        exit 1
    fi
done
(
    umask 077
    mkdir -p "$signing"
    if [[ ! -e "$signing/shanghai-release.p12" ]]; then
        if [[ ! -e "$signing/password" ]]; then
            python3 -c 'import secrets; print(secrets.token_urlsafe(38))' > "$signing/password"
        fi
        keytool -genkeypair -storetype PKCS12 -keystore "$signing/shanghai-release.p12" \
            -storepass:file "$signing/password" -alias shanghai-release -keyalg RSA -keysize 3072 \
            -validity 10000 -dname 'CN=Shanghai Open World, O=Shanghai Open World'
    fi
    if [[ ! -s "$signing/password" ]]; then
        printf 'Project keystore exists but its password file is missing. Restore the original pair.\n' >&2
        exit 1
    fi
    keytool -exportcert -rfc -keystore "$signing/shanghai-release.p12" -storepass:file "$signing/password" \
        -alias shanghai-release -file "$signing/public-certificate.pem"
)
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$signing/shanghai-release.p12"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=shanghai-release
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(<"$signing/password")"
tools/configure_editor.py "$sdk" "$java_home"
tools/godot.sh --headless --editor --import
tools/godot.sh --headless --export-release Android "$output"
"$buildtools/apksigner" verify --verbose --print-certs "$output"
"$buildtools/zipalign" -c -P 16 -v 4 "$output" > "$out_dir/zipalign.txt"
"$buildtools/aapt" dump badging "$output" > "$out_dir/badging.txt"
"$buildtools/aapt" dump xmltree "$output" AndroidManifest.xml > "$out_dir/manifest.txt"
unzip -tq "$output"
(cd "$out_dir" && sha256sum "$(basename "$output")" > SHA256SUMS)
