---
title: Portfolio Tab
description: Live OCT/USD price, 7-day chart, and per-wallet value breakdown.
section: Features
order: 3
---

The Portfolio tab was added in **v1.0.2** and shows the real-time USD value of your OCT holdings.

## What's Shown

- **Total portfolio value** in USD (sum of all wallets)
- **24h price change** badge — percentage and direction
- **7-day OCT/USD chart** — interactive, tap any point to see the exact price
- **Per-wallet breakdown** — each wallet's OCT balance and current USD value

## Price Source

Prices are fetched from the [CoinGecko public API](https://www.coingecko.com) on every pull-to-refresh. The app does not cache prices between sessions.

## Refreshing

Pull down on the Portfolio tab to refresh the price and recalculate all USD values. If the network is unavailable, the last known price is not shown — the portfolio displays dashes until a fresh price is fetched.

## Notes

- USD values are **indicative only** — OCT trading may be illiquid and prices can differ between venues
- Private (shielded) OCT balances are **not** included in the portfolio total since decrypting them on-demand would incur network costs
