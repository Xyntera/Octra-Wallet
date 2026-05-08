# Architecture Decision

## Chosen approach

Use Flutter for the APK UI and move wallet-core responsibilities into a native
library exposed through a Flutter bridge. Do not run a local server inside the
app.

Current implementation uses the vendored `native/vendor/webcli/pvac` C++ PVAC backend through a
C ABI. A Rust backend can replace it later if an equivalent Rust PVAC crate is
provided.

## Why

The older `Octra-Wallet` Flutter app was a client that owned its own local
wallet state and network calls. The newer `webcli` codebase shows that the
wallet domain has expanded into a more complete core with:

- account / wallet manifests
- HD derivation metadata
- balance and history aggregation
- private-feature orchestration
- transaction signing and canonicalization

That logic is better expressed as a shared native core than as a server process
or a pure Dart rewrite.

## What this means

- Flutter owns UI, navigation, and app state.
- The native core owns wallet-domain logic, signing, derivation, and native
  crypto.
- The bridge should be `dart:ffi` or a Flutter plugin wrapper around the native
  library.
- The APK must not depend on an HTTP daemon running on the device.

## Scope for this fork

The app remains intentionally read-only for now:

- public balance
- transaction history
- wallet selection
- local PIN access control

## Role of `webcli`

`webcli` is now the architectural reference for behavior and wallet-core
semantics, not the runtime backend.

## Later expansion

Once the native bridge is stable, the missing wallet-core features can be added
back in layers without reintroducing a server boundary.
