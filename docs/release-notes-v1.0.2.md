# Octra Wallet v1.0.2 Release Notes

## Summary

v1.0.2 adds a Portfolio tab with live OCT price data and per-wallet USD
breakdown, fixes two production bugs (white overlay blocking UI after wallet
import, history stuck in loading state), and includes UI polish throughout.

## New Features

### Portfolio Tab

A third tab in `HomeTabScaffold` (`lib/ui/portfolio.dart`) showing:

- **Total value card** — combined OCT holdings converted to USD at live price,
  with a 24h change badge (green up / red down).
- **7-day price chart** — interactive `fl_chart` `LineChart` sourced from
  CoinGecko. Touch any point to see the exact price.
- **Per-wallet breakdown** — each wallet in the multi-wallet list shows its
  individual OCT balance and USD equivalent.

Price data is fetched from CoinGecko with a 5-minute in-memory cache.
`WalletController` exposes `fetchPriceData()`, `fetchAllWalletBalances()`,
`invalidatePriceCache()`, `octPrice`, `priceChange24h`, `priceHistory`, and
`walletPublicBalances`.

### UI Polish

- Action buttons on the home screen now animate with `AnimatedScale` (scale to
  0.88 on press, 120 ms ease-out) for a tactile native feel.
- Wallet-picker bottom sheet dynamically sizes its height based on wallet count
  instead of being fixed.
- All deprecated `withOpacity()` calls replaced with `withValues(alpha:)`.

## Bug Fixes

### White overlay blocking UI after wallet import

**Root cause:** `_PvacBusyOverlay` used `Positioned.fill` nested inside
`AnimatedOpacity > IgnorePointer`. `Positioned.fill` must be a direct `Stack`
child. On Android release builds (assertions disabled) this caused the 70%
black `ColoredBox` to render as a permanent grey wash over the entire screen
even when `isPvacBusy = false`, blocking all interaction.

**Fix:** Replaced the `AnimatedOpacity + IgnorePointer + Positioned.fill`
structure with a conditional render — `SizedBox.shrink()` when not busy,
`SizedBox.expand()` with a `ColoredBox` when busy. The widget is completely
removed from the tree when not needed.

### History stuck in loading state

**Root cause:** `WalletController.refresh()` set `isLoading = false` inside a
`finally` block that was guarded by `if (!_isActiveRefresh)`. A concurrent
refresh that incremented `_refreshSerial` would skip the reset, leaving
`isLoading` permanently `true`.

**Fix:** `isLoading = false` and `notifyListeners()` moved outside the guard so
they always execute in the finally block.

### `isPvacBusy` could be permanently stuck

`_runPvacTask` only reset `isPvacBusy` inside `if (showProgress)`. If
`task()` hung, `isPvacBusy` would stay `true` forever.

**Fix:** `isPvacBusy = false` moved outside the `showProgress` guard.
Added `.timeout(const Duration(seconds: 120))` on the task call to prevent
indefinite hangs.

## Native Runtime

Same as v1.0.1 — the Android APK includes:

- `liboctra_core.so`
- `libcrypto.so`
- `libc++_shared.so`

Supported ABIs: `arm64-v8a`, `x86_64`.

## New Dependencies

- `fl_chart: ^0.69.0` — 7-day price line chart in Portfolio tab.

## Known Limits (carry-forward from v1.0.1)

- iOS Flutter app target and App Store packaging still pending.
- Bulk private transactions not included.
- DApp browser / provider injection not included.
- Android release signing should use a production keystore before Play Store distribution.
