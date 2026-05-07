# Migration Plan

## Phase 1

Keep the existing Flutter app and trim the UI to the read-only scope.

## Phase 2

Replace the temporary wallet-core assumptions with a Rust bridge:

- Rust native wallet library
- Rust native wallet library built around `pvac-rs`
- Flutter FFI or plugin boundary
- no local HTTP server inside the APK
- iOS static library build
- Android shared library build

Status: bridge scaffold added. Flutter can now attempt to load the native
library and fall back while the real `pvac-rs` implementation is integrated.

## Phase 3

Keep the Flutter state layer focused on:

- unlock
- wallet selection
- public balance
- history
- watch-only support
- security gating
- localization

## Phase 4

Add back additional core capabilities only after the Rust bridge is stable:

- private transfers
- stealth claim scanning
- token import
- bulk transactions
- DApp browser injection
- address book
- fee recommendations
- proxy-backed history and pending tracking
