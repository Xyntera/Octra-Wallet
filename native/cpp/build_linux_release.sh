#!/usr/bin/env bash
# Portable Linux build of the Octra PVAC core for distribution
# (no -march=native; suitable for bundling into the Flutter Linux app).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEBCLI_DIR="${WEBCLI_DIR:-$REPO_ROOT/native/vendor/webcli}"
OUT_DIR="$SCRIPT_DIR/target/linux"

mkdir -p "$OUT_DIR"

gcc -O2 -fPIC \
  -c "$WEBCLI_DIR/lib/tweetnacl.c" \
  -o "$OUT_DIR/tweetnacl.o"

gcc -O2 -fPIC \
  -c "$WEBCLI_DIR/lib/randombytes.c" \
  -o "$OUT_DIR/randombytes.o"

# PVAC requires hardware AES; AES-NI is present on effectively all
# x86-64 CPUs from the last decade, unlike the rest of -march=native.
g++ -std=c++17 -O2 -fPIC -pthread -maes -shared \
  "$SCRIPT_DIR/octra_core.cpp" \
  "$WEBCLI_DIR/pvac/pvac_c_api.cpp" \
  "$OUT_DIR/tweetnacl.o" \
  "$OUT_DIR/randombytes.o" \
  -I"$WEBCLI_DIR" \
  -I"$WEBCLI_DIR/lib" \
  -I"$WEBCLI_DIR/pvac" \
  -I"$WEBCLI_DIR/pvac/include" \
  -lcrypto \
  -o "$OUT_DIR/liboctra_core.so"

strip --strip-unneeded "$OUT_DIR/liboctra_core.so" 2>/dev/null || true

echo "$OUT_DIR/liboctra_core.so"
