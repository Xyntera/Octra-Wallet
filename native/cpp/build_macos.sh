#!/usr/bin/env bash
# macOS build of the Octra PVAC core (liboctra_core.dylib).
# Requires: brew install openssl@3
# OpenSSL is linked statically so the dylib is self-contained; the app
# bundles it under Contents/Frameworks (see octra_core_bridge.dart).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEBCLI_DIR="${WEBCLI_DIR:-$REPO_ROOT/native/vendor/webcli}"
OUT_DIR="$SCRIPT_DIR/target/macos"
OPENSSL_PREFIX="${OPENSSL_PREFIX:-$(brew --prefix openssl@3)}"
# Single-arch by default (matches the build host); override with
# MACOS_ARCH=x86_64 on Intel runners.
MACOS_ARCH="${MACOS_ARCH:-$(uname -m)}"

# PVAC requires hardware AES: Apple Silicon has the arm64 crypto
# extensions by default; Intel needs AES-NI enabled explicitly.
ARCH_FLAGS=()
if [[ "$MACOS_ARCH" == "x86_64" ]]; then
  ARCH_FLAGS+=(-maes)
fi

mkdir -p "$OUT_DIR"

clang -O2 -fPIC -arch "$MACOS_ARCH" \
  -c "$WEBCLI_DIR/lib/tweetnacl.c" \
  -o "$OUT_DIR/tweetnacl.o"

clang -O2 -fPIC -arch "$MACOS_ARCH" \
  -c "$WEBCLI_DIR/lib/randombytes.c" \
  -o "$OUT_DIR/randombytes.o"

clang++ -std=c++17 -O2 -fPIC -arch "$MACOS_ARCH" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} -dynamiclib \
  "$SCRIPT_DIR/octra_core.cpp" \
  "$WEBCLI_DIR/pvac/pvac_c_api.cpp" \
  "$OUT_DIR/tweetnacl.o" \
  "$OUT_DIR/randombytes.o" \
  -I"$WEBCLI_DIR" \
  -I"$WEBCLI_DIR/lib" \
  -I"$WEBCLI_DIR/pvac" \
  -I"$WEBCLI_DIR/pvac/include" \
  -I"$OPENSSL_PREFIX/include" \
  "$OPENSSL_PREFIX/lib/libcrypto.a" \
  -install_name @rpath/liboctra_core.dylib \
  -o "$OUT_DIR/liboctra_core.dylib"

echo "$OUT_DIR/liboctra_core.dylib"
