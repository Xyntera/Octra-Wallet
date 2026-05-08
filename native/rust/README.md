# Octra Rust Core

This crate is the native core boundary for Octra Wallet mobile.

## Outputs

- Android: `liboctra_core.so`
- iOS: `liboctra_core.a`

## Current status

The crate currently exports a stable FFI scaffold. It does not yet link the
real `pvac-rs` implementation.

The working native PVAC backend is now in `native/cpp/`, using the local
`native/vendor/webcli/pvac` C++ implementation. Keep this Rust scaffold as
a future option only if a real Rust `pvac-rs` crate becomes available.

The npm package `@0xio/pvac` was inspected and contains browser JavaScript plus
WASM artifacts. It is useful as API reference, but Flutter needs platform-native
libraries. In this workspace, those libraries can be built from the C++
`webcli/pvac` source instead of the npm package.

## Package inspection performed

`@0xio/pvac` was not installed into the Flutter app. It was downloaded and
inspected from the public npm registry only:

```bash
npm view @0xio/pvac version dist.tarball repository description
npm pack @0xio/pvac --pack-destination /tmp
```

The inspected package was:

- package: `@0xio/pvac`
- version: `1.0.1`
- tarball: `https://registry.npmjs.org/@0xio/pvac/-/pvac-1.0.1.tgz`
- repository: `https://github.com/0xio-xyz/0xio-pvac.git`

The tarball contains `dist/` JavaScript files and `wasm/pvac_rs_bg.wasm`.
That means compiled `pvac-rs` code is present only as a browser WASM binary.
It does not contain the Rust source, `Cargo.toml`, Android `.so` files, or iOS
`.a` static libraries.

The package repository was also checked:

```bash
git ls-remote https://github.com/0xio-xyz/0xio-pvac.git
git clone --depth 1 https://github.com/0xio-xyz/0xio-pvac.git /tmp/0xio-pvac-src
```

That repository is publicly readable and contains TypeScript sources plus the
bundled WASM package. It does not contain a `Cargo.toml` or Rust source files,
so it cannot produce the native Flutter mobile libraries by itself.

For Flutter, the app should link native Rust outputs directly:

- Android loads `liboctra_core.so` with Dart FFI.
- iOS links `liboctra_core.a` into the Runner or a Flutter plugin.
- The npm package remains only an API/behavior reference unless the actual
  Rust `pvac-rs` source or prebuilt native artifacts are added.

## Local Rust toolchain

Rust was installed locally under the workspace, not globally:

```text
CARGO_HOME=/home/username/oct/.cargo
RUSTUP_HOME=/home/username/oct/.rustup
```

Use this environment when building:

```bash
export CARGO_HOME=/home/username/oct/.cargo
export RUSTUP_HOME=/home/username/oct/.rustup
export PATH=/home/username/oct/.cargo/bin:$PATH
```

## Host verification

The scaffold can be compiled directly with `rustc` because it currently has no
external dependencies:

```bash
CARGO_HOME=/home/username/oct/.cargo \
RUSTUP_HOME=/home/username/oct/.rustup \
PATH=/home/username/oct/.cargo/bin:$PATH \
rustc --crate-name octra_core --edition=2021 --crate-type cdylib \
  native/rust/src/lib.rs \
  -O \
  -o native/rust/target/local/liboctra_core.so
```

This verifies the ABI on the host. It is not a replacement for Android NDK or
iOS cross-compilation.

## Android build targets

Install targets:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
```

Build:

```bash
cargo build --release --target aarch64-linux-android
```

Copy the built shared libraries into:

```text
android/app/src/main/jniLibs/<abi>/liboctra_core.so
```

## iOS build targets

Install targets:

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
```

Build:

```bash
cargo build --release --target aarch64-apple-ios
```

The final iOS integration should expose `liboctra_core.a` through the Flutter
iOS runner or a dedicated Flutter plugin.
