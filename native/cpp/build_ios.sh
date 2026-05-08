#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEBCLI_DIR="${WEBCLI_DIR:-$REPO_ROOT/native/vendor/webcli}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required. Run this on macOS with Xcode installed." >&2
  exit 1
fi

if [[ -z "${OPENSSL_IOS_INCLUDE:-}" ]]; then
  echo "OPENSSL_IOS_INCLUDE is required for stealth AES-GCM headers." >&2
  echo "The final iOS app target must also link an iOS libcrypto/OpenSSL XCFramework." >&2
  exit 1
fi

IOS_MIN_VERSION="${IOS_MIN_VERSION:-13.0}"

build_sdk() {
  local sdk="$1"
  local arch="$2"
  local target="$3"
  local sdk_path
  local out_dir="$SCRIPT_DIR/target/ios/$sdk-$arch"
  local cc
  local cxx
  local libtool

  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  cc="$(xcrun --sdk "$sdk" --find clang)"
  cxx="$(xcrun --sdk "$sdk" --find clang++)"
  libtool="$(xcrun --sdk "$sdk" --find libtool)"

  mkdir -p "$out_dir"

  "$cc" -O2 -fPIC -arch "$arch" -target "$target" \
    -mios-version-min="$IOS_MIN_VERSION" -isysroot "$sdk_path" \
    -c "$WEBCLI_DIR/lib/tweetnacl.c" \
    -o "$out_dir/tweetnacl.o"

  "$cc" -O2 -fPIC -arch "$arch" -target "$target" \
    -mios-version-min="$IOS_MIN_VERSION" -isysroot "$sdk_path" \
    -c "$WEBCLI_DIR/lib/randombytes.c" \
    -o "$out_dir/randombytes.o"

  "$cxx" -std=c++17 -O2 -fPIC -arch "$arch" -target "$target" \
    -mios-version-min="$IOS_MIN_VERSION" -isysroot "$sdk_path" \
    -I"$WEBCLI_DIR" \
    -I"$WEBCLI_DIR/lib" \
    -I"$WEBCLI_DIR/pvac" \
    -I"$WEBCLI_DIR/pvac/include" \
    -I"$OPENSSL_IOS_INCLUDE" \
    -c "$SCRIPT_DIR/octra_core.cpp" \
    -o "$out_dir/octra_core.o"

  "$cxx" -std=c++17 -O2 -fPIC -arch "$arch" -target "$target" \
    -mios-version-min="$IOS_MIN_VERSION" -isysroot "$sdk_path" \
    -I"$WEBCLI_DIR" \
    -I"$WEBCLI_DIR/lib" \
    -I"$WEBCLI_DIR/pvac" \
    -I"$WEBCLI_DIR/pvac/include" \
    -I"$OPENSSL_IOS_INCLUDE" \
    -c "$WEBCLI_DIR/pvac/pvac_c_api.cpp" \
    -o "$out_dir/pvac_c_api.o"

  "$libtool" -static \
    "$out_dir/octra_core.o" \
    "$out_dir/pvac_c_api.o" \
    "$out_dir/tweetnacl.o" \
    "$out_dir/randombytes.o" \
    -o "$out_dir/liboctra_core.a"

  echo "$out_dir/liboctra_core.a"
}

build_sdk iphoneos arm64 arm64-apple-ios
build_sdk iphonesimulator arm64 arm64-apple-ios-simulator
