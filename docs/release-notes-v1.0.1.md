# Octra Wallet v1.0.1 Release Notes

## Summary

Octra Wallet v1.0.1 is the current production Android APK release of the
Flutter native mobile wallet with local PVAC privacy operations. The APK
packages native Octra wallet-core libraries and performs privacy proof/decrypt
work on-device.

## Highlights

- Multi-wallet management with create, import, watch-only, rename, and color
  customization flows.
- Public OCT send and bulk public send, capped at 5 recipients.
- Native PVAC key registration, encrypt, decrypt, stealth send, stealth scan,
  and stealth claim flows.
- Dynamic fee recommendations per operation type before transaction
  confirmation.
- OctraScan-backed transaction history scoped to the active wallet.
- Custom token import by contract address, token list, token removal, and token
  transfer.
- PIN and biometric confirmation before transaction-changing operations.
- Export options for private key and seed phrase.
- Dark native Flutter UI with keyboard-aware sheets and PVAC progress overlay.

## Native Runtime

The Android APK includes:

- `liboctra_core.so`
- `libcrypto.so`
- `libc++_shared.so`

Supported release ABIs:

- `arm64-v8a`
- `x86_64`

PVAC operations are routed through `lib/native/pvac_worker.dart`, which runs
native calls in a serialized background isolate. This prevents long proof
generation from freezing Flutter animations or triggering Android ANR dialogs.

## Validation

GitHub Actions release validation passed for:

- Flutter dependency install and analysis
- host native PVAC build and smoke test
- Android OpenSSL build
- Android native core build
- Android runtime library verification
- Android release APK build
- iOS native static archive build

Release workflow:

```text
Flutter Native Mobile
```

Validated run:

```text
https://github.com/Xyntera/Octra-Wallet/actions/runs/25539133431
```

## Known Limits

- iOS native static libraries are built, but a committed Flutter iOS app target
  and final App Store packaging are still pending.
- DApp browser/provider injection is not included in this release.
- Bulk private transactions and private token operations are not included in
  this release.
- Android release signing should be configured with a production keystore before
  Play Store distribution.
