# GitHub Actions Build Setup

Do not put personal access tokens in workflow files or chat logs. If a token is
ever pasted into a chat, revoke it and create a new one.

## Vendored Native PVAC Source

The workflow is self-contained. It does not check out `webcli` anymore.

The required Octra Labs `webcli` native files are vendored under:

```text
native/vendor/webcli
```

The vendored source comes from:

```text
origin https://github.com/octra-labs/webcli
license GPL-2.0-or-later with an OpenSSL linking exception
```

The Flutter wallet native core depends on these vendored files:

```text
native/vendor/webcli/pvac
native/vendor/webcli/lib/stealth.hpp
native/vendor/webcli/lib/tweetnacl.c
native/vendor/webcli/lib/randombytes.c
```

Build scripts still accept `WEBCLI_DIR=/path/to/webcli` as an override for local
experiments, but CI uses the vendored copy.

## Workflow

The workflow lives at:

```text
.github/workflows/flutter-native-mobile.yml
```

Jobs:

- `flutter-checks`: runs `flutter pub get`, `flutter analyze`, and tests if a
  `test/` directory exists.
- `native-host`: builds Linux `liboctra_core.so` and runs the native smoke test.
- `android-apk`: builds Android OpenSSL, builds native `.so` libraries, then
  builds a release APK artifact.
- `ios-native`: builds iOS native static archives on macOS.

## Android Outputs

Artifacts:

- `octra-wallet-release-apk`
- `android-native-libs`

The Android job builds OpenSSL for:

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

Then it packages both `liboctra_core.so` and `libcrypto.so` under:

```text
android/app/src/main/jniLibs
```

## iOS Status

The workflow builds native static archives:

```text
native/cpp/target/ios/iphoneos-arm64/liboctra_core.a
native/cpp/target/ios/iphonesimulator-arm64/liboctra_core.a
```

The Flutter iOS app project is not present in this repository yet. A later step
must generate or commit the iOS Flutter project and link:

- `liboctra_core.a`
- an iOS-compatible OpenSSL/libcrypto XCFramework
