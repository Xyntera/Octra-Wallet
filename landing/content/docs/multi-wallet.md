---
title: Multi-Wallet Management
description: Create, import, rename, and manage multiple wallets in one app.
section: Features
order: 4
---

Octra Wallet supports multiple wallets in a single app instance. Each wallet has its own address, balance, history, and PVAC state.

## Adding a Wallet

Tap the wallet switcher icon (top-right on the Home tab) → **Add Wallet**, then choose:

- **Create new** — generates a fresh HD wallet with a new seed phrase
- **Import seed phrase** — restore from 12 BIP-39 words
- **Import private key** — paste a base64 Ed25519 key

## Switching Wallets

Tap the wallet name in the header or use the wallet switcher sheet. Switching is instant — balances and history reload for the selected wallet automatically.

## Renaming & Colors

In the wallet switcher, long-press a wallet (or tap the edit icon) to:

- **Rename** the wallet
- **Assign a color** for easy visual identification

## Exporting / Backing Up

Tap the wallet menu → **Export** to access:

- **Private key** (base64)
- **Seed phrase** (12 words)

Store these offline. Losing them means permanent loss of funds — there is no server recovery.

## Deleting a Wallet

From the wallet menu, tap **Delete Wallet**. This removes the wallet from the app only — the on-chain address and funds remain accessible if you have the private key or seed phrase.
