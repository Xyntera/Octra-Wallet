# Feature Wire-Up Status

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
  - native stealth helpers from `native/vendor/webcli/lib/stealth.hpp`

- Flutter wallet controller:
  - public balance refresh from RPC
  - transaction history refresh from RPC
  - encrypted balance fetch with signed `octra_encryptedBalance` request
  - encrypted balance decrypt through native PVAC
  - PVAC pubkey generation and registration
  - native encrypt-balance payload generation
  - native decrypt-balance payload generation
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

## Newly Wired Native Stealth Features

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

Stealth send preparation is wired, but full proof generation can be slow because
it requires multiple range proofs. A long host smoke test exceeded the useful
interactive wait window, so this path needs dedicated performance testing.

## Still Not Fully Wired

- Stealth send proof-generation performance validation
- Bulk private transactions
- Token private operations
- DApp browser/provider injection
- Address book
- Push notifications
- Biometric confirmation for future DApp-provider flows
- Android/iOS native packaging validation on real toolchains

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

Android native `.so` outputs require Android NDK:

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

The final iOS app target must link a matching iOS `libcrypto` or OpenSSL
XCFramework because stealth helpers use AES-GCM.
