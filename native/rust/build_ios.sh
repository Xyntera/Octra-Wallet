#!/usr/bin/env bash
set -euo pipefail

crate_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cargo build --release --target aarch64-apple-ios --manifest-path "$crate_dir/Cargo.toml"

echo "$crate_dir/target/aarch64-apple-ios/release/liboctra_core.a"
