#!/usr/bin/env bash
set -euo pipefail

crate_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$crate_dir/../.." && pwd)"

declare -A targets=(
  ["arm64-v8a"]="aarch64-linux-android"
  ["armeabi-v7a"]="armv7-linux-androideabi"
  ["x86"]="i686-linux-android"
  ["x86_64"]="x86_64-linux-android"
)

for abi in "${!targets[@]}"; do
  target="${targets[$abi]}"
  cargo build --release --target "$target" --manifest-path "$crate_dir/Cargo.toml"
  mkdir -p "$project_dir/android/app/src/main/jniLibs/$abi"
  cp "$crate_dir/target/$target/release/liboctra_core.so" \
    "$project_dir/android/app/src/main/jniLibs/$abi/liboctra_core.so"
done
