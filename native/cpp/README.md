# Octra Native C++ Core

This native core wraps the vendored `native/vendor/webcli/pvac` implementation and exports the
same C ABI consumed by Flutter through `lib/native/octra_core_bridge.dart`.

## Why C++ Here

The wallet repository vendors the required native PVAC implementation under:

```text
native/vendor/webcli/pvac
```

That implementation exposes a C API:

```text
native/vendor/webcli/pvac/pvac_c_api.h
native/vendor/webcli/pvac/pvac_c_api.cpp
```

It is not Rust, but it is native and can be loaded by Flutter through the same
Dart FFI bridge. The language behind the ABI is invisible to Dart.

## Implemented Operations

Call `octra_core_execute_privacy_operation` with JSON:

```json
{
  "op": "register_pubkey",
  "private_key_b64": "..."
}
```

Supported `op` values:

- `register_pubkey`
- `fhe_encrypt`
- `fhe_decrypt`
- `encrypt_balance`
- `decrypt_balance`
- `derive_view_keypair`
- `stealth_prepare_send`
- `stealth_scan_outputs`
- `stealth_prepare_claim`

`fhe_encrypt`, `encrypt_balance`, and `decrypt_balance` require caller-provided
secure random values:

- `seed_b64`: 32 bytes
- `blinding_b64`: 32 bytes for balance operations

The Flutter layer should generate these values with platform secure randomness.

## Host Build

```bash
native/cpp/build_host.sh
```

Output:

```text
native/cpp/target/local/liboctra_core.so
```

## Android Build

Requires Android NDK plus Android OpenSSL/BoringSSL headers and libraries for
the stealth AES-GCM helpers:

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
export OPENSSL_ANDROID_INCLUDE=/path/to/openssl/include
export OPENSSL_ANDROID_LIB_DIR=/path/to/openssl/android/libs
native/cpp/build_android.sh
```

Outputs:

```text
android/app/src/main/jniLibs/arm64-v8a/liboctra_core.so
android/app/src/main/jniLibs/armeabi-v7a/liboctra_core.so
android/app/src/main/jniLibs/x86_64/liboctra_core.so
```

`OPENSSL_ANDROID_LIB_DIR` may either point at a directory containing
ABI-specific subdirectories such as `arm64-v8a/libcrypto.so`, or at a flat
directory containing the target ABI `libcrypto`.

## iOS Build

Requires macOS, Xcode, OpenSSL headers, and a matching iOS libcrypto/OpenSSL
XCFramework linked by the final app target:

```bash
export OPENSSL_IOS_INCLUDE=/path/to/openssl/include
native/cpp/build_ios.sh
```

Outputs:

```text
native/cpp/target/ios/iphoneos-arm64/liboctra_core.a
native/cpp/target/ios/iphonesimulator-arm64/liboctra_core.a
```
