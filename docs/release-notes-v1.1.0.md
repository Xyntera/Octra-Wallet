# Octra Wallet v1.1.0

The first multi-platform release: Octra Wallet now ships for **Android, Windows, macOS, and Linux**, all running the native PVAC privacy core on-device.

## Highlights

### Desktop support (new)
- **Windows x64** — portable zip; the PVAC core ships as a fully static `octra_core.dll` (no runtimes to install)
- **macOS (Apple Silicon)** — signed `.app` bundle with the PVAC core in `Contents/Frameworks`
- **Linux x64** — portable tar.gz bundle; the PVAC core is bundled in `lib/`
- All desktop builds are produced and checksummed by GitHub Actions on every release tag

### PVAC core updated to upstream 0.05.01-alpha
- Synced with the latest `octra-labs/webcli` PVAC: scoped seeded-encryption domains, canonical scalar/point validation on every deserialize, cipher/public-key shape checks, and hardened R1CS verifier input bounds
- New error-checked commitment APIs (`pvac_commit_ct_v2`, `pvac_pedersen_commit_v2`)
- Wire format unchanged — existing encrypted balances and history remain fully compatible

### Private operations: reliability fixes
- **Fixed: decrypt and private send timing out.** Proof budgets were far below what phone-class CPUs need; decrypt/stealth now get realistic limits and the two stealth range proofs are generated on parallel threads (matching webcli)
- The progress overlay shows a live elapsed timer, so multi-minute proofs no longer look frozen

### UI overhaul
- Send/Encrypt/Decrypt/Token/Bulk sheets keep your input and re-enable the button when an operation fails, instead of closing and discarding everything
- Human-readable error messages in place of raw exception dumps
- Redesigned Receive screen (framed QR with quiet zone, monospace address, copy confirmation), unified bottom sheets with drag handles, animated balances, pull-to-refresh + relative timestamps in History, themed empty states, haptic feedback throughout
- QR scanner is now reachable from the recipient field in Public Send and Private Send (Android/iOS/macOS)
- Recipient address sanity check catches typos before signing
- "Lock Now" immediately engages the PIN gate
- `flutter analyze` clean: 0 issues

### Network
- Default mainnet RPC migrated to `https://octra.network` (HTTPS); devices still pointing at the retired `http://46.101.86.250:8080` endpoint are migrated automatically on startup

## Install

| Platform | Asset | How to run |
|---|---|---|
| Android 6.0+ | `Octra-Wallet-v1.1.0-android.apk` | Sideload (enable *Install unknown apps*); arm64 + x86_64 |
| Windows 10/11 x64 | `Octra-Wallet-v1.1.0-windows-x64.zip` | Extract, run `ouqro_wallet.exe` |
| macOS 11+ (Apple Silicon) | `Octra-Wallet-v1.1.0-macos-arm64.zip` | Extract, right-click the app → **Open** (first launch only) |
| Linux x64 | `Octra-Wallet-v1.1.0-linux-x64.tar.gz` | `tar -xzf`, run `./octra-wallet/ouqro_wallet` |

Linux needs OpenSSL 3 and GTK 3 (preinstalled on Ubuntu 22.04+/Debian 12+/Fedora 36+ and newer). The Linux keyring (libsecret/gnome-keyring) is used for secure storage.

## Verify downloads

Every asset is listed in `SHA256SUMS.txt`:

```
sha256sum -c SHA256SUMS.txt --ignore-missing
```

## Notes and limits

- Desktop binaries are not signed with paid certificates yet: Windows SmartScreen and macOS Gatekeeper will warn on first launch (use *More info → Run anyway* / right-click → *Open*)
- Privacy proofs (encrypt, decrypt, private send, claim) are heavy zero-knowledge computations and take **several minutes** — the in-app timer shows progress
- Camera QR scanning is not available on Windows/Linux desktop (no camera plugin support); the scan button hides itself there
- macOS build targets Apple Silicon (arm64); Intel Macs need a local build via `native/cpp/build_macos.sh` + `flutter build macos`
