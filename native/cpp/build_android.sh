#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEBCLI_DIR="${WEBCLI_DIR:-$REPO_ROOT/native/vendor/webcli}"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ANDROID_NDK_HOME is required" >&2
  exit 1
fi

if [[ -z "${OPENSSL_ANDROID_INCLUDE:-}" || -z "${OPENSSL_ANDROID_LIB_DIR:-}" ]]; then
  echo "OPENSSL_ANDROID_INCLUDE and OPENSSL_ANDROID_LIB_DIR are required for stealth AES-GCM support" >&2
  echo "Build or provide Android OpenSSL/BoringSSL headers and per-ABI libcrypto before running this script." >&2
  exit 1
fi

API="${ANDROID_API:-24}"
HOST_TAG="${ANDROID_HOST_TAG:-linux-x86_64}"
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"

build_abi() {
  local abi="$1"
  local triple="$2"
  local arch_flags="$3"
  local compiler="$TOOLCHAIN/${triple}${API}-clang++"
  local c_compiler="$TOOLCHAIN/${triple}${API}-clang"
  local out_dir="$REPO_ROOT/android/app/src/main/jniLibs/$abi"
  local obj_dir="$SCRIPT_DIR/target/android/$abi"

  if [[ ! -x "$compiler" ]]; then
    echo "missing compiler: $compiler" >&2
    exit 1
  fi

  mkdir -p "$out_dir" "$obj_dir"

  "$c_compiler" -O2 $arch_flags -fPIC \
    -c "$WEBCLI_DIR/lib/tweetnacl.c" \
    -o "$obj_dir/tweetnacl.o"

  "$c_compiler" -O2 $arch_flags -fPIC \
    -c "$WEBCLI_DIR/lib/randombytes.c" \
    -o "$obj_dir/randombytes.o"

  "$compiler" -std=c++17 -O2 $arch_flags -fPIC -shared \
    "$SCRIPT_DIR/octra_core.cpp" \
    "$WEBCLI_DIR/pvac/pvac_c_api.cpp" \
    "$obj_dir/tweetnacl.o" \
    "$obj_dir/randombytes.o" \
    -I"$WEBCLI_DIR" \
    -I"$WEBCLI_DIR/lib" \
    -I"$WEBCLI_DIR/pvac" \
    -I"$WEBCLI_DIR/pvac/include" \
    -I"$OPENSSL_ANDROID_INCLUDE" \
    -L"$OPENSSL_ANDROID_LIB_DIR/$abi" \
    -L"$OPENSSL_ANDROID_LIB_DIR" \
    -lcrypto \
    -o "$out_dir/liboctra_core.so"

  echo "$out_dir/liboctra_core.so"
}

build_abi arm64-v8a aarch64-linux-android "-march=armv8-a+crypto"
build_abi armeabi-v7a armv7a-linux-androideabi "-march=armv7-a+crypto"
build_abi x86_64 x86_64-linux-android "-maes"
