---
title: "Understanding PVAC: How Octra's On-Device Privacy Works"
date: "2026-04-20"
description: "A deep dive into PVAC (Private Value and Computation) — how it encrypts balances, enables stealth transfers, and why running it on-device matters."
author: Glaqz
tags: [privacy, pvac, technical]
---

PVAC (Private Value and Computation) is the privacy layer built into the Octra network. Here's how it works and why Octra Wallet runs it natively on your phone.

## What PVAC Does

The Octra network has two balance types for every address:

- **Public balance** — visible on-chain, like a standard blockchain account
- **Private balance** — encrypted, shielded from public view

PVAC lets you move value between these two states:

1. **Encrypt** — convert public OCT into private, shielded OCT
2. **Decrypt** — reveal and convert private OCT back to your public balance
3. **Stealth send** — transfer private OCT to a recipient without revealing the amount or recipient on-chain
4. **Scan & claim** — discover stealth outputs sent to you and bring them into your balance

## Why On-Device Matters

Every PVAC proof involves cryptographic computation that takes 1–5 seconds on a modern phone. **Octra Wallet compiles the PVAC C++ library into the APK** as `liboctra_core.so` and calls it via Dart FFI.

This means:
- Your private keys never leave the device
- No PVAC server can be surveilled or seized
- Proofs are generated locally without network round trips

## The Background Isolate Pattern

Long PVAC operations run in a Dart background isolate via `Isolate.run()`. This keeps the UI thread free — you can navigate, read balances, and check history while a stealth send computes in the background.

Each isolate call re-opens the native library internally and communicates via JSON over the FFI bridge.
