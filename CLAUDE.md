# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Analyze (lint)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Build Linux desktop (CI: .github/workflows/flutter-desktop.yml)
native/cpp/build_linux_release.sh   # portable PVAC core -> native/cpp/target/linux/
flutter build linux --release       # CMake bundles the .so into bundle/lib/

# Build Windows desktop (run the DLL script from an MSYS2 MinGW64 shell)
native/cpp/build_windows_msys2.sh   # static octra_core.dll -> native/cpp/target/windows/
flutter build windows --release     # CMake bundles the DLL next to the exe

# Build macOS desktop
native/cpp/build_macos.sh           # liboctra_core.dylib -> native/cpp/target/macos/
flutter build macos --release       # then copy the dylib into <app>/Contents/Frameworks

# Build native C++ library for local host testing (required for PVAC on desktop)
native/cpp/build_host.sh
# Output: native/cpp/target/local/liboctra_core.so
```

## Architecture

### Layer Overview

The app has three distinct runtime layers:

1. **Flutter UI** — navigation, wallet selection, state presentation, PIN gate
2. **WalletController** (`lib/wallet.dart`) — the single `ChangeNotifier` registered via `Provider`. Owns all wallet state: balances, history, tokens, PVAC status. All UI reads from and writes through this controller.
3. **Native PVAC core** — C++ library loaded via Dart FFI (`liboctra_core.so` on Android/Linux, process image on iOS). If the library fails to load, a `NoopOctraCoreBridge` is substituted silently and all privacy operations become unavailable (`nativeCore.isAvailable == false`).

### Startup Flow

`main()` initializes `WalletController` before `runApp`. `StartupCheck` then runs:
1. If a PIN is set and security is enabled → push `PinScreen`, loop until success
2. If a wallet exists → `HomeTabScaffold`
3. Otherwise → `WalletSetupPage`

### Key Files

| File | Role |
|---|---|
| `lib/wallet.dart` | `WalletController` — all business logic and network calls |
| `lib/models.dart` | `Wallet` model — address, privateKeyBase64, mnemonic, name, color |
| `lib/rpc.dart` | `RpcClient` — HTTP + JSON-RPC 2.0 calls to `https://octra.network` |
| `lib/native/octra_core_bridge.dart` | `OctraCoreBridge` abstract + `FfiOctraCoreBridge` (real FFI) + `NoopOctraCoreBridge` fallback |
| `lib/native/pvac_worker.dart` | `PvacWorker` — serializes PVAC ops through background isolates (`Isolate.run`) |
| `lib/native/pvac_operations.dart` | `PvacOperations` — lower-level direct bridge wrapper (not used by `WalletController`; `PvacWorker` is) |
| `lib/address.dart` | `octraAddressFromPubKey` — SHA-256 → base58 → `oct` prefix |
| `lib/utils/derivation.dart` | HD key derivation matching `walletgen.js` (`deriveForNetwork` uses path `m/345h/0h/0h/0h/0h/0h/0h/0`) |
| `lib/utils/crypto.dart` | AES-256-GCM client-side balance encryption (v2 format) and legacy v1 fallback |
| `lib/ui/home.dart` | `HomeTabScaffold` — main tabs, all transaction UIs |
| `native/cpp/octra_core.cpp` | C ABI wrapper exposing `octra_core_*` symbols over the vendored PVAC C++ |
| `native/vendor/webcli/pvac` | Vendored upstream PVAC C++ implementation |

### PVAC / Native Bridge Pattern

Privacy operations (encrypt, decrypt, stealth send/claim) are CPU-heavy. They go through `PvacWorker`, which queues them as a serial chain of `Isolate.run` calls to avoid blocking the UI thread. Each isolate call re-opens the native library internally.

The `OctraCoreBridge` interface communicates with the native library entirely through JSON strings passed over FFI. All calls pass a JSON payload and receive a JSON result; the bridge owns freeing the native-allocated string via `octra_core_free_string`.

### Amount Handling

All amounts on the wire and in storage are in **micro-OCT** (1 OCT = 1,000,000 micro). The constant `kMicro = 1000000` is defined in `lib/rpc.dart`. Display conversions happen at the UI layer only.

### Transaction Signing

`WalletController._canonicalTxJson` produces the exact JSON string that is signed with Ed25519. Field order is fixed: `from`, `to_`, `amount`, `nonce`, `ou`, `timestamp`, `op_type`, then optionally `encrypted_data` and `message`. The recipient field is `to_` (underscore), not `to`.

Nonces are computed as `max(on-chain nonce, max staged nonce) + 1`. The staging pool is checked via `staging_view` RPC before every transaction to handle pending transactions correctly.

### Wallet Persistence

`flutter_secure_storage` is the only persistence layer. Keys used:
- `wallets` — JSON array of all wallets
- `last_selected_wallet` — address string
- `user_pin` — raw PIN string
- `security_enabled` — boolean string
- `custom_tokens_<address>` — JSON array of custom token contract addresses per wallet

At load time, `WalletController` re-derives the address from the stored private key and repairs any mismatch before saving.

### RPC Strategy

`RpcClient` attempts JSON-RPC 2.0 at `POST /rpc` first for most operations, then falls back to REST endpoints if the RPC call fails or returns an error. This dual-path is intentional for network compatibility.

### Native Library Platforms

| Platform | Library |
|---|---|
| Android | `liboctra_core.so` (with pre-loaded `libc++_shared.so` and `libcrypto.so`) |
| iOS | Linked statically; loaded from process image |
| macOS | `liboctra_core.dylib` in `Contents/Frameworks` (falls back to process image) |
| Linux | `liboctra_core.so` |
| Windows | `octra_core.dll` |

Android JNI libs go in `android/app/src/main/jniLibs/<ABI>/`.
