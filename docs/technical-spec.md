# Technical Specification

## Scope

The app is a Flutter APK client with a native wallet core. The initial UI shows
only:

- public balance
- transaction history

The target product includes:

- multi-wallet management
- create wallet
- import wallet
- watch-only wallet
- public and private token transfers
- bulk transaction support up to 5 recipients
- stealth transfer claiming
- custom token import by contract address
- biometric unlock
- PIN lock with rate limiting and auto-lock timeout
- DApp browser with wallet provider injection
- history with pending tracking
- address book
- QR code scan and generation
- internationalization
- dark theme
- hide balances toggle
- RPC proxy for history loading
- dual-network history
- Sentry crash reporting
- recommended fees per operation type
- production-readiness screens and warnings

## Supported UI

- startup / unlock check
- wallet setup
- home dashboard
- history page
- wallet switcher
- privacy operation screens
- token import screen
- DApp browser
- settings and security screens
- address book

## Data model

Wallet data remains local and includes:

- address
- private key base64
- optional mnemonic
- display name
- wallet color
- watch-only flag
- network preference
- token list
- contact list
- security settings

## Runtime responsibilities

Flutter is responsible for:

- rendering the dashboard
- handling PIN lock state
- managing local UI state
- handling biometrics and accessibility UI
- handling localization and theme state

The native core is responsible for:

- wallet-core derivation and canonicalization
- transaction signing
- native crypto integration
- manifest / account semantics
- parity-sensitive wallet-core operations
- privacy encryption and claim logic
- fee estimation helpers
- transaction assembly for bulk recipients

## Bridge contract

The Flutter bridge should expose a small set of stable methods, starting with:

- wallet version / health
- active wallet metadata
- public balance snapshot
- transaction history snapshot
- transaction detail lookup
- privacy operation execution
- token import and removal
- fee recommendation lookup
- stealth scan and claim support

The bridge can be implemented with `dart:ffi` or a Flutter plugin depending on
how much platform-specific setup is needed on Android and iOS.

## Native Backend

Current backend:

- `native/cpp/octra_core.cpp`
- vendored `native/vendor/webcli/pvac` C++ PVAC implementation
- Dart FFI through `lib/native/octra_core_bridge.dart`

The Rust scaffold remains available, but the working PVAC backend is C++ because
that is the native source present in the workspace.

## Delivery Phasing

The first delivery started read-only. The next phase can add UI flows for the
native PVAC operations now exposed by the bridge:

- private transfer execution
- stealth send / claim
- DApp provider injection
- push notifications
- dual-network sync and proxying

## Libraries

Current Flutter dependencies remain useful for the client shell:

- `provider`
- `flutter_secure_storage`
- `http`
- `bip39`
- `cryptography`
- `flutter_animate`
- `google_fonts`
- `flutter_localizations`
- `intl`
- `local_auth`
- `sentry_flutter`
- `webview_flutter`

Native backend changes can be introduced without changing the Flutter UI stack
first as long as the C ABI contract remains stable.
