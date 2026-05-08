# PVAC NPM Package in Flutter

## Question

Can the npm package `@0xio/pvac` be used directly in the Flutter Android/iOS
build?

## Short answer

Not as the native mobile core.

The package includes compiled `pvac-rs` as WebAssembly, but it does not include
the Rust source or platform-native mobile libraries.

## What the package contains

The inspected npm package contains:

- `dist/*.js`
- `dist/*.d.ts`
- `wasm/pvac_rs.js`
- `wasm/pvac_rs_bg.wasm`
- `wasm/snippets/wasm-bindgen-rayon-*/`

The package does not contain:

- `Cargo.toml`
- Rust `.rs` source files
- Android `.so` libraries
- iOS `.a` static libraries
- iOS/macOS `.dylib` libraries

## Why this matters

Flutter Android/iOS should call native code through one of these paths:

- `dart:ffi` loading `liboctra_core.so` on Android
- `dart:ffi` or a Flutter plugin linked to `liboctra_core.a` on iOS

The npm package is built for JavaScript environments. Its WASM glue expects a
JavaScript runtime, `WebAssembly`, JS `BigInt`, typed arrays, dynamic imports,
and rayon web worker helper code.

That shape fits browsers, extensions, and web workers. It does not fit a normal
Flutter mobile build as a direct dependency.

## Possible but not recommended options

### Hidden WebView bridge

Flutter could load the JS/WASM bundle inside Android WebView and iOS WKWebView,
then call it through a JavaScript channel.

This is technically possible, but it is not recommended for the wallet core:

- harder to secure and audit
- slower bridge boundary for proof-heavy operations
- harder lifecycle and memory management
- inconsistent behavior between Android WebView and iOS WKWebView
- not a native library build
- breaks the original goal of native Rust mobile cryptography

### Embedded JavaScript runtime

Flutter could embed a JS engine and try to run the wasm-bindgen package there.

This is also not recommended:

- WebAssembly support varies by embedded engine
- worker/rayon support is difficult
- package glue is browser-oriented
- iOS restrictions and performance become risky

### Flutter Web only

For Flutter Web, the package can be used through JavaScript interop. That does
not solve Android APK or iOS IPA native builds.

## Updated Path After Workspace Inspection

The workspace contains native PVAC source in:

```text
native/vendor/webcli/pvac
```

That source is C++ with a C API. It is not from the npm package, but it provides
the native implementation needed for mobile.

Current implementation now uses this shape:

```text
Flutter UI
  -> Dart OctraCoreBridge
    -> liboctra_core.so / liboctra_core.a
      -> native C ABI wrapper
        -> native/vendor/webcli/pvac C++ PVAC implementation
```

This is better than using npm WASM through WebView because it keeps PVAC in a
native library and avoids a JavaScript bridge for wallet-core cryptography.

## Recommended path

Use the npm package only as an API and wire-format reference.

For the mobile app, keep this structure:

```text
Flutter UI
  -> Dart OctraCoreBridge
    -> liboctra_core.so on Android
    -> liboctra_core.a on iOS
      -> native C ABI wrapper
        -> native/vendor/webcli/pvac C++ implementation
```

If a real Rust `pvac-rs` crate is later provided, it can replace the C++ backend
behind the same Dart FFI contract.

## Current repo status

This repository already has:

- Dart bridge scaffold: `lib/native/octra_core_bridge.dart`
- Rust FFI scaffold: `native/rust/src/lib.rs`
- C++ PVAC FFI implementation: `native/cpp/octra_core.cpp`
- C++ build scripts: `native/cpp/build_host.sh`, `native/cpp/build_android.sh`
- Android/iOS native build scripts: `native/rust/build_android.sh`,
  `native/rust/build_ios.sh`

The native contract is intentionally shaped so the backend can change without
rewriting the Flutter UI.
