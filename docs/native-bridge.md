# Native Bridge Contract

## Goal

Expose wallet-core behavior from Rust to Flutter without running a local HTTP
server on the device.

## Target stack

- Flutter for UI and app state
- native wallet-core logic loaded through a stable C ABI
- vendored `native/vendor/webcli/pvac` C++ implementation for current PVAC operations
- Rust remains a possible future wrapper if a Rust `pvac-rs` crate is provided
- `dart:ffi` or a Flutter plugin bridge
- iOS static library output
- Android shared library output

## `@0xio/pvac` Package Check

The npm package `@0xio/pvac` was inspected from the npm registry:

- version: `1.0.1`
- tarball: `https://registry.npmjs.org/@0xio/pvac/-/pvac-1.0.1.tgz`
- repository: `https://github.com/0xio-xyz/0xio-pvac.git`
- package shape: JavaScript bindings plus bundled WASM

The package README states it is browser/WASM oriented. It does not ship Android
`.so` or iOS `.a` native mobile libraries. For Flutter mobile, the usable path
is the underlying Rust/native implementation, not `npm install @0xio/pvac`
inside the Flutter app.

## Initial bridge surface

The bridge should start small and stable:

- `version()`
- `health()`
- `publicSnapshot(address)`
- `historySnapshot(address, limit, offset)`
- `txDetails(hash)`
- `executePrivacyOperation(payload)`
- `recommendFee(operationType, recipientCount)`
- `scanStealthInbox(address)`
- `importToken(contractAddress)`

## Data flow

Flutter should treat the Rust layer as the source of truth for wallet-core
behavior. The UI should only present:

- public balance
- history
- wallet selection
- local PIN state
- biometric state
- token list
- address book entries

## Notes

The Rust code in this repository is a scaffold. It defines the ABI shape first
so the Flutter app can be wired before the full native core is complete.

The bridge should be designed around a small number of JSON commands or a flat
binary schema so Flutter can remain platform-neutral while the native library
evolves.

## Implemented Files

- Dart bridge: `lib/native/octra_core_bridge.dart`
- Rust ABI: `native/rust/src/lib.rs`
- C++ PVAC ABI: `native/cpp/octra_core.cpp`
- C++ host build helper: `native/cpp/build_host.sh`
- C++ Android build helper: `native/cpp/build_android.sh`
- Android build helper: `native/rust/build_android.sh`
- iOS build helper: `native/rust/build_ios.sh`
- Android output location: `android/app/src/main/jniLibs/`

## Native PVAC Source Found

The workspace contains a local native PVAC implementation in:

```text
native/vendor/webcli/pvac
```

This is C++ with a C API, not Rust. It exposes functions such as:

- `pvac_keygen_from_seed`
- `pvac_enc_value_seeded`
- `pvac_dec_value_fp`
- `pvac_make_zero_proof_bound`
- `pvac_make_range_proof`
- `pvac_serialize_cipher`

The Flutter app can still use it through Dart FFI because the app only needs a
stable C ABI.

The host build was verified with:

```bash
native/cpp/build_host.sh
```

Smoke-tested operations:

- `octra_core_health`
- `fhe_encrypt`
- `fhe_decrypt`

The encrypt/decrypt round trip returned the original test amount.

## Current Behavior

Flutter attempts to load the native library first:

- Android: `liboctra_core.so`
- iOS/macOS: symbols from the process image
- Linux: `liboctra_core.so`
- Windows: `octra_core.dll`

If the library is unavailable, the bridge falls back to a no-op implementation
and the current wallet controller continues using the direct read-only network
path for public balance and history.
