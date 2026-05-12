---
title: PVAC Privacy Operations
description: How to use encrypt, decrypt, stealth send, and scan in Octra Wallet.
section: Features
order: 2
---

## Prerequisites

Before using PVAC, you must **Register PVAC Key**. Tap the Privacy button on the Home tab and select Register. This derives your PVAC key pair from your wallet seed and registers it on-chain (costs a small fee).

## Encrypt (Public → Private)

Converts public OCT into a shielded private balance.

1. Home tab → **Encrypt**
2. Enter the amount of OCT to shield
3. Confirm the fee estimate
4. Tap **Encrypt** — the operation runs in a background isolate (1–5 seconds)

Your private balance increases once the transaction confirms.

## Decrypt (Private → Public)

Reveals and moves private OCT back to your public balance.

1. Home tab → **Decrypt**
2. Enter amount to reveal (up to your current private balance)
3. Confirm and tap **Decrypt**

## Stealth Send

Sends OCT privately. Only you and the recipient can see the transfer.

1. Home tab → **Private Send**
2. Enter recipient address and amount
3. Tap **Send** — PVAC generates a one-time stealth address on-device

The recipient must **Scan** to discover outputs sent to them.

## Scan & Claim

Discovers stealth outputs addressed to you.

1. Home tab → **Scan**
2. The wallet scans recent blocks for outputs addressed to your PVAC key
3. Found outputs appear in the Claim list
4. Tap **Claim** on each output to add it to your private balance

## Troubleshooting

**"PVAC not available"** — The native library failed to load. Reinstall the APK or check that your Android ABI (arm64 or x86_64) is supported.

**Operation stuck** — If a PVAC operation hangs, the app will automatically reset after a timeout. Pull to refresh on the Home tab.
