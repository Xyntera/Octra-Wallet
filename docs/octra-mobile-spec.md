# Octra Wallet Mobile Spec

## Product Goal

Build a native iOS and Android wallet in Flutter for Octra Wallet, with privacy
operations powered by a Rust native core based on `pvac-rs`.

The app should ship as a standard mobile wallet, not a server process.

## Branding

- Product name: Octra Wallet
- Remove all `0xio` branding
- Use the Octra visual identity only

## Runtime Architecture

- Flutter UI
- Rust native crypto and wallet core
- `dart:ffi` or Flutter plugin bridge
- iOS static library packaging
- Android shared library packaging
- no local HTTP server

## Core Capabilities

- multi-wallet management
- create wallet
- import wallet
- watch-only wallet
- public balance
- private balance
- public token transfers
- private token transfers
- bulk transfers to up to 5 recipients
- stealth transfer claiming with automatic scanning
- custom token import by contract address
- transaction history with pending state
- address book
- QR code scan and generation
- hide balances toggle
- dual-network history for mainnet and devnet
- dynamic fee recommendations

## Security and Privacy

- biometric authentication
- PIN lock
- rate limiting on failed unlocks
- auto-lock timeout
- secure clipboard with auto-clear
- backup reminder for unprotected wallets
- screenshot and screen recording prevention
- root and jailbreak warning detection
- transaction confirmation with biometric or PIN re-authentication
- secure key storage on device

## DApp and Connectivity

- DApp browser
- wallet provider injection
- RPC proxy for faster history loading
- network connection indicator
- push notifications

## Internationalization

Languages:

- English
- Bahasa Indonesia
- Chinese
- Japanese
- Korean

## Reporting and Reliability

- Sentry crash reporting
- accessibility labels and hints throughout
- dark theme

## Flutter Package Direction

Recommended Flutter equivalents for the previous Expo/RN stack:

- `flutter_secure_storage`
- `local_auth`
- `sentry_flutter`
- `go_router` or `auto_route`
- `flutter_riverpod` or `provider`
- `dio` or `http`
- `webview_flutter` or `flutter_inappwebview`
- `mobile_scanner`
- `qr_flutter`
- `firebase_messaging` for push notifications if needed
- `intl` and `flutter_localizations`

## Rust Core Direction

The Rust core should expose:

- mnemonic and key derivation
- signing
- address generation
- public and private transfer construction
- FHE encryption and decryption
- stealth claim logic
- bulk transaction assembly
- fee recommendations
- token metadata handling

## Delivery Stance

The first deliverable should focus on:

- public balance
- history
- multi-wallet support
- security shell
- Rust bridge scaffolding

Then the privacy operations can be filled in behind the same interface.
