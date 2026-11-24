#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
umask 022
cache="$root/tools/downloads"
local_tools="$root/tools/local"
sdk="$root/tools/android-sdk"
version=4.7.2
templates="$local_tools/xdg/data/godot/export_templates/$version.stable"
mkdir -p "$cache" "$local_tools" "$sdk/build-tools" "$sdk/platforms" "$templates"
godot_url="https://github.com/godotengine/godot-builds/releases/download/$version-stable"
google="https://dl.google.com/android/repository"
jdk_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.17%2B10"
jdk_file="OpenJDK17U-jdk_x64_linux_hotspot_17.0.17_10.tar.gz"

download() {
    local file="$1" url="$2"
    if [[ ! -s "$file" ]]; then
        curl --fail --location --retry 2 --output "$file.part" "$url"
        mv "$file.part" "$file"
    fi
}

check_sha256() {
    printf '%s  %s\n' "$1" "$2" | sha256sum --check --status
}

check_sha1() {
    printf '%s  %s\n' "$1" "$2" | sha1sum --check --status
}

if ! command -v "${GODOT_BIN:-godot}" >/dev/null && [[ ! -x "$local_tools/godot" ]]; then
    name="Godot_v$version-stable_linux.x86_64"
    download "$cache/godot-sha512.txt" "$godot_url/SHA512-SUMS.txt"
    download "$cache/$name.zip" "$godot_url/$name.zip"
    (cd "$cache" && grep "  $name.zip$" godot-sha512.txt | sha512sum --check)
    unzip -j -o "$cache/$name.zip" "$name" -d "$local_tools"
    mv "$local_tools/$name" "$local_tools/godot"
fi
if ! [[ -s "$templates/android_release.apk" && -s "$templates/web_nothreads_release.zip" ]]; then
    download "$cache/templates.tpz" "$godot_url/Godot_v$version-stable_export_templates.tpz"
    check_sha256 f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011 "$cache/templates.tpz"
    unzip -j -o "$cache/templates.tpz" templates/android_release.apk 'templates/web_nothreads_*.zip' templates/linux_release.x86_64 -d "$templates"
fi
if [[ ! -x "$local_tools/jdk17/bin/javac" && -z "${JAVA_HOME:-}" ]]; then
    download "$cache/jdk17.tar.gz" "$jdk_url/$jdk_file"
    download "$cache/jdk17.sha256.txt" "$jdk_url/$jdk_file.sha256.txt"
    read -r digest _ < "$cache/jdk17.sha256.txt"
    check_sha256 "$digest" "$cache/jdk17.tar.gz"
    mkdir -p "$local_tools/jdk17"
    tar -xzf "$cache/jdk17.tar.gz" -C "$local_tools/jdk17" --strip-components 1
fi
if [[ ! -x "$sdk/build-tools/36.0.0/apksigner" ]]; then
    archive=build-tools_r36_linux.zip
    download "$cache/$archive" "$google/$archive"
    check_sha1 b0b6376977657e8ad9b969bacf4093601da2c6fb "$cache/$archive"
    unzip -q -o "$cache/$archive" -d "$cache/unpacked"
    cp -a "$cache/unpacked/android-16" "$sdk/build-tools/36.0.0"
fi
if [[ ! -s "$sdk/platforms/android-36/android.jar" ]]; then
    archive=platform-36_r02.zip
    download "$cache/$archive" "$google/$archive"
    check_sha1 2c1a80dd4d9f7d0e6dd336ec603d9b5c55a6f576 "$cache/$archive"
    unzip -q -o "$cache/$archive" -d "$sdk/platforms"
fi
if [[ ! -x "$sdk/platform-tools/adb" ]]; then
    archive=platform-tools_r37.0.3-linux.zip
    download "$cache/$archive" "$google/$archive"
    check_sha1 e1579b288a7ae4e9bc28dedec6a154d78b3c04ed "$cache/$archive"
    unzip -q -o "$cache/$archive" -d "$sdk"
fi
if ! PYTHONPATH="$local_tools${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'from shapely import constrained_delaunay_triangles; import PIL'; then
    python3 -m pip install --target "$local_tools" -r tools/requirements-map.txt
fi
printf 'Toolchain ready in %s\n' "$root/tools"
