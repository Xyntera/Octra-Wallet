# Octra Wallet Architecture

## Current direction

This repository stays as the Octra Wallet Flutter app, but the runtime target is
now:

- Flutter UI
- native wallet core exposed through a stable C ABI
- vendored `native/vendor/webcli/pvac` C++ backend for current PVAC operations
- `dart:ffi` or Flutter plugin bridge
- no local server process
- iOS static library output
- Android shared library output

## Legacy app behavior

The original Flutter wallet had:

- local wallet storage
- mnemonic import
- private key import
- send / encrypt / decrypt / private transfer flows
- history display
- encrypted balance display

## `webcli` reference architecture

The `webcli` repository shows the newer wallet-core shape. It is the behavioral
reference for:

- account manifest logic
- wallet file format
- HD derivation metadata
- transaction canonicalization
- balance / history aggregation
- private-feature orchestration

That code is not the runtime target for the APK.

## Native crypto core

The privacy and signing layer should be split into a native surface, not an
Expo module:

- PVAC privacy operations
- C ABI wrapper for Flutter FFI
- platform-native packaging for iOS and Android

The native side should own:

- mnemonic and seed derivation
- Ed25519 signing
- public and private transfer construction
- stealth claim scanning
- privacy encryption and decryption
- bulk transaction assembly
- recommended fee calculation

## Flutter client target

Flutter remains the UI shell, while the native library becomes the wallet core
behind it. The app scope starts from read-only and now has native privacy
building blocks available:

- unlock
- choose wallet
- display public balance
- display transaction history
- switch wallets locally
- support watch-only wallets
- support token and account metadata

## What we are changing now

- keep the existing Octra visual style
- remove private actions from the visible UI
- stop using temporary server-style client shims
- introduce a native bridge boundary for wallet-core work
- keep the app in-place in this repository
