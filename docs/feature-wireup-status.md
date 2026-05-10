# Feature Wire-Up Status

## Production Release Status

The current Android release build has native PVAC packaged and validated through
GitHub Actions. Heavy PVAC operations are executed through a serialized Flutter
isolate worker so range proofs and decrypt/proof preparation do not block the
main UI isolate.

Release validation completed for:

- Flutter analysis
- host native PVAC build and smoke test
- Android OpenSSL build
- Android native `liboctra_core.so` build
- Android release APK build
- APK runtime library verification for `arm64-v8a` and `x86_64`
- iOS native static archive build

## Wired Now

- Direct Octra JSON-RPC client path:
  - `octra_balance`
  - `octra_account`
  - `staging_view`
  - `octra_transaction`
  - `octra_submit`
  - `octra_publicKey`
  - `octra_encryptedBalance`
  - `octra_encryptedCipher`
  - `octra_pvacPubkey`
  - `octra_registerPvacPubkey`

- Native PVAC backend:
  - vendored `native/vendor/webcli/pvac` C++ implementation
  - `native/cpp/octra_core.cpp` C ABI wrapper
  - Flutter `dart:ffi` bridge
  - serialized `PvacWorker` background isolate execution
  - native stealth helpers from `native/vendor/webcli/lib/stealth.hpp`

- Flutter wallet controller:
  - public balance refresh from RPC
  - transaction history refresh from RPC
  - encrypted balance fetch with signed `octra_encryptedBalance` request
  - encrypted balance decrypt through native PVAC
  - PVAC pubkey generation and registration
  - native encrypt-balance payload generation
  - native decrypt-balance payload generation
  - native PVAC calls off the UI isolate
  - canonical transaction signing compatible with `webcli`
  - signed `octra_submit` for encrypt/decrypt transactions
  - stealth transfer preparation
  - stealth output scan
  - stealth claim transaction preparation
  - public send transaction signing
  - bulk public transfer signing and sequential submission, capped at 5 recipients
  - token discovery through `octra_listContracts`
  - custom token import by contract address
  - token transfer as signed contract call payloads

- Portfolio tab (v1.0.2):
  - live OCT/USD price fetch from CoinGecko with 5-minute cache
  - 24h price change percentage badge (green/red)
  - 7-day price chart via `fl_chart` `LineChart` with touch tooltips
  - per-wallet OCT balance and USD value breakdown
  - `invalidatePriceCache` / `fetchPriceData` / `fetchAllWalletBalances` on `WalletController`
  - `isPriceFetching` loading state and refresh button in nav bar

- Flutter UI:
  - public balance card
  - private balance card
  - native PVAC status text
  - PVAC key registration action
  - encrypt public OCT action
  - decrypt private OCT action
  - stealth private send action
  - stealth scan and claim action
  - public send action
  - bulk public send action
  - token list/import/send sheet
  - swipe-to-delete imported token entries
  - PIN/biometric confirmation before public send, bulk public send, encrypt, decrypt, private send, and claim
  - full-screen PVAC progress overlay during long native privacy work (v1.0.2: fixed rendering artifact where `Positioned.fill` inside `AnimatedOpacity` caused a grey wash on Android release builds; replaced with conditional `SizedBox.shrink()` / `SizedBox.expand()`)
  - `_runPvacTask` always resets `isPvacBusy` in finally block with 120s timeout guard

- Bug fixes (v1.0.2):
  - history stuck loading: `isLoading` now always resets in `refresh()` finally block regardless of concurrent refresh serial
  - PVAC overlay blocking UI after wallet import: removed invalid `Positioned.fill` nesting

## Native Stealth Features

- `derive_view_keypair`
- `stealth_prepare_send`
- `stealth_scan_outputs`
- `stealth_prepare_claim`

Flutter controller methods:

- `makePrivateTransfer`
- `scanStealthTransfers`
- `claimStealthTransfer`

RPC support:

- `octra_stealthOutputs`
- signed `octra_submit` for `op_type=stealth`
- signed `octra_submit` for `op_type=claim`

## Native Smoke Tests Passed

Host `liboctra_core.so` was rebuilt from:

```text
native/cpp/octra_core.cpp
native/vendor/webcli/pvac/pvac_c_api.cpp
```

Smoke-tested:

- `register_pubkey`
- `encrypt_balance`
- `fhe_decrypt`
- `derive_view_keypair`
- `stealth_scan_outputs`
- `stealth_prepare_claim`

The generated encrypted cipher decrypted back to the original test amount.

Stealth send preparation is wired. Because full proof generation can be CPU
intensive, the Flutter app now runs it through the PVAC worker instead of the UI
thread.

## Still Open

- Bulk private transactions
- Token private operations
- DApp browser/provider injection
- Address book
- Push notifications
- Biometric confirmation for future DApp-provider flows
- committed Flutter iOS app target and App Store packaging

## Transaction Confirmation Status

The Flutter UI now calls the existing `PinScreen(isChecking: true)` before
privacy-changing actions. If security is enabled and a PIN exists, that screen
auto-prompts biometrics where the platform supports it and falls back to PIN.

Covered:

- public OCT send
- bulk public OCT send
- token transfer
- encrypt public OCT into private balance
- decrypt private OCT into public balance
- stealth private send
- stealth claim

Not covered yet:

- private bulk send, because stealth proof generation needs performance
  validation first
- DApp-provider initiated transactions, because the DApp browser is not built
  yet

## Android/iOS Blocker

Android native `.so` outputs are built in CI with Android NDK and packaged into
the APK. Local Android native builds require:

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
export OPENSSL_ANDROID_INCLUDE=/path/to/openssl/include
export OPENSSL_ANDROID_LIB_DIR=/path/to/openssl/android/libs
native/cpp/build_android.sh
```

iOS static library outputs require macOS/Xcode and OpenSSL headers:

```bash
export OPENSSL_IOS_INCLUDE=/path/to/openssl/include
native/cpp/build_ios.sh
```

The final iOS app target must link the generated `liboctra_core.a` plus a
matching iOS `libcrypto` or OpenSSL XCFramework because stealth helpers use
AES-GCM.
