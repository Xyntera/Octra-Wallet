---
title: "Octra Wallet v1.0.2 Released — Portfolio Tab, Bug Fixes"
date: "2026-05-10"
description: "Version 1.0.2 brings a live Portfolio tab with OCT/USD price tracking, a 7-day chart, and three production bug fixes."
author: Glaqz
tags: [release, portfolio, bug-fixes]
---

We're releasing **Octra Wallet v1.0.2** with a major new feature and several important fixes.

## What's New

### Portfolio Tab

The new **Portfolio** tab shows your entire OCT holdings at a glance:

- **Live OCT/USD price** fetched from CoinGecko on every refresh
- **7-day interactive chart** — tap any point to inspect the exact price
- **24h change badge** — green for positive, red for negative
- **Per-wallet breakdown** — OCT balance and USD value for every wallet

### Bug Fixes

**White overlay after wallet import** — A white shader was rendered over the UI immediately after importing a wallet via private key or seed phrase. This made the app unusable until restart. Fixed by resetting the overlay state on wallet load.

**History loading on cold start** — Transaction history sometimes failed to load on the first open after install because the RPC client wasn't fully initialized. Fixed with proper async sequencing in WalletController startup.

**isPvacBusy timeout** — Long PVAC operations (encrypt, stealth send) could leave `isPvacBusy = true` permanently if an isolate threw. Added a timeout + finally reset so the UI always unlocks.

## Download

Get the APK from the [Releases page](https://github.com/Xyntera/Octra-Wallet/releases/tag/v1.0.2).

```
Octra-Wallet-v1.0.2-android.apk
Minimum Android: 6.0 (API 23)
ABIs: arm64-v8a, x86_64
License: GPL-2.0-or-later
```
