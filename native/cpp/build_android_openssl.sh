#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ANDROID_NDK_HOME is required" >&2
  exit 1
fi

OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.2}"
ANDROID_API="${ANDROID_API:-24}"
ANDROID_HOST_TAG="${ANDROID_HOST_TAG:-linux-x86_64}"
OUT_DIR="${OPENSSL_ANDROID_OUT:-$SCRIPT_DIR/target/openssl-android}"
SRC_ROOT="$SCRIPT_DIR/target/openssl-src"
TARBALL="$SRC_ROOT/openssl-$OPENSSL_VERSION.tar.gz"
SOURCE_DIR="$SRC_ROOT/openssl-$OPENSSL_VERSION"
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$ANDROID_HOST_TAG/bin"

if [[ ! -d "$TOOLCHAIN" ]]; then
  echo "missing Android NDK toolchain: $TOOLCHAIN" >&2
  exit 1
fi

mkdir -p "$SRC_ROOT" "$OUT_DIR/libs"

if [[ ! -f "$TARBALL" ]]; then
  curl -L "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o "$TARBALL"
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  tar -xzf "$TARBALL" -C "$SRC_ROOT"
fi

export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export PATH="$TOOLCHAIN:$PATH"

build_abi() {
  local abi="$1"
  local target="$2"
  local build_dir="$SCRIPT_DIR/target/openssl-build/$abi"
  local prefix="$OUT_DIR/prefix/$abi"
  local lib_dir

  rm -rf "$build_dir" "$prefix"
  mkdir -p "$(dirname "$build_dir")" "$prefix" "$OUT_DIR/libs/$abi"
  cp -R "$SOURCE_DIR" "$build_dir"

  pushd "$build_dir" >/dev/null
  ./Configure "$target" shared no-tests no-apps no-docs \
    --prefix="$prefix" \
    -D__ANDROID_API__="$ANDROID_API"
  make -j"$(getconf _NPROCESSORS_ONLN)"
  make install_sw
  popd >/dev/null

  lib_dir="$prefix/lib"
  if [[ -d "$prefix/lib64" ]]; then
    lib_dir="$prefix/lib64"
  fi
  cp "$lib_dir/libcrypto.so" "$OUT_DIR/libs/$abi/libcrypto.so"
  mkdir -p "$REPO_ROOT/android/app/src/main/jniLibs/$abi"
  cp "$lib_dir/libcrypto.so" "$REPO_ROOT/android/app/src/main/jniLibs/$abi/libcrypto.so"
}

build_abi arm64-v8a android-arm64
build_abi armeabi-v7a android-arm
build_abi x86_64 android-x86_64

cat >"$OUT_DIR/env.sh" <<EOF
export OPENSSL_ANDROID_INCLUDE="$OUT_DIR/prefix/arm64-v8a/include"
export OPENSSL_ANDROID_LIB_DIR="$OUT_DIR/libs"
EOF

echo "$OUT_DIR/env.sh"
