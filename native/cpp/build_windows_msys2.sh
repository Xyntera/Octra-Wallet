#!/usr/bin/env bash
# Windows build of the Octra PVAC core (octra_core.dll).
# Run from an MSYS2 MinGW64 shell with:
#   pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-openssl
# The DLL is linked fully statically (gcc runtime, winpthread, OpenSSL),
# so it has no MinGW runtime DLL dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEBCLI_DIR="${WEBCLI_DIR:-$REPO_ROOT/native/vendor/webcli}"
OUT_DIR="$SCRIPT_DIR/target/windows"

mkdir -p "$OUT_DIR"

gcc -O2 \
  -c "$WEBCLI_DIR/lib/tweetnacl.c" \
  -o "$OUT_DIR/tweetnacl.o"

gcc -O2 \
  -c "$WEBCLI_DIR/lib/randombytes.c" \
  -o "$OUT_DIR/randombytes.o"

# PVAC requires hardware AES (AES-NI).
g++ -std=c++17 -O2 -maes -shared -static \
  "$SCRIPT_DIR/octra_core.cpp" \
  "$WEBCLI_DIR/pvac/pvac_c_api.cpp" \
  "$OUT_DIR/tweetnacl.o" \
  "$OUT_DIR/randombytes.o" \
  -I"$WEBCLI_DIR" \
  -I"$WEBCLI_DIR/lib" \
  -I"$WEBCLI_DIR/pvac" \
  -I"$WEBCLI_DIR/pvac/include" \
  -lcrypto -lws2_32 -lgdi32 -lcrypt32 -lbcrypt \
  -o "$OUT_DIR/octra_core.dll"

strip --strip-unneeded "$OUT_DIR/octra_core.dll" 2>/dev/null || true

echo "$OUT_DIR/octra_core.dll"
