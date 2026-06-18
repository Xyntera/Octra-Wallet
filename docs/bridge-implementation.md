# OCT ↔ wOCT Bridge — Implementation Spec & Status

In-app Ethereum wallet + Octra↔Ethereum bridge so users can wrap native **OCT**
into **wOCT** (an ERC‑20 on Ethereum mainnet) and unwrap it back, from inside
Octra Wallet.

> The bridge is **not** part of `octra-labs/webcli`. It is a separate, already
> deployed Octra protocol on Ethereum mainnet, documented at
> `docs.octra.org/oct-docs/{bridging,wrapped-oct,contract-addresses}`, with
> public reference UIs (`bridge.0xio.xyz`, `octra-bridge.vercel.app`,
> `octrabridge.site`).

## Verified mainnet contracts (pinned in `lib/eth/eth_constants.dart`)

| Contract | Address | Role |
|---|---|---|
| wOCT (ERC‑20) | `0x4647e1fE715c9e23959022C2416C71867F5a6E80` | Wrapped OCT token |
| EthereumBridge | `0xE7eD69b852fd2a1406080B26A37e8E04e7dA4caE` | Mints wOCT on claim, burns on unwrap |
| OctraLightClient | `0xC01cA57dc7f7C4B6f1B6b87B85D79e5ddf0dF55d` | Verifies Octra bridge headers/epochs on Ethereum |

Chain id 1 (mainnet). 1:1 supply, 0 protocol fee.

## Flow

**OCT → wOCT (lock-and-mint):**
1. Lock OCT on Octra via the bridge vault; the lock message encodes the ETH
   recipient + amount (min 1 OCT).
2. Wait ~30–40 min for the epoch to finalize on Ethereum (verified by
   OctraLightClient).
3. **Claim** on Ethereum → EthereumBridge mints wOCT to the recipient.

**wOCT → OCT (burn-and-unlock):**
1. `approve` wOCT to the bridge.
2. `burn`/bridge call on Ethereum with the destination **Octra** address.
3. Octra-side unlock releases native OCT.

## Ethereum key/recipient modes (all three, per product decision)

- **Derived (in-app):** `EthAccount.fromMnemonic` → BIP44 `m/44'/60'/0'/0/0`,
  secp256k1 + Keccak‑256 + EIP‑55; app signs ETH/bridge txs.
- **WalletConnect (external MetaMask):** app builds txs, user signs externally;
  app never holds the key.
- **Manual address:** `EthAccount.fromAddress` — recipient-only (cannot sign,
  so usable only as the wrap destination).

## Status

**Implemented (this pass, CI-validated):**
- `lib/eth/eth_constants.dart` — pinned addresses/params.
- `lib/eth/eth_account.dart` — derived + manual modes, EIP‑55, address
  validation.
- `test/eth/eth_account_test.dart` — known-answer derivation vector
  (Hardhat account #0) + checksum/validation tests.
- `pubspec.yaml` — `web3dart`, `bip32` deps.

**Remaining (needs confirmed specs + a Dart build + mainnet testing):**
- `lib/eth/eth_rpc.dart` — `Web3Client` wrapper: ETH balance/nonce/gas,
  EIP‑1559 send; wOCT `decimals`/`balanceOf`/`allowance`/`approve`/`transfer`
  (standard ERC‑20 ABI — no external fetch needed).
- `lib/eth/bridge.dart` — wrap (Octra lock + epoch tracking + Ethereum claim)
  and unwrap (approve + burn). **Spec-blocked items**, do not guess:
  1. wOCT **`decimals()`** — read on-chain; OCT is 6‑dp micro-OCT, do not
     assume 18 when converting amounts.
  2. EthereumBridge **ABI** (claim/mint + burn signatures) — obtain from
     Etherscan (verified source, needs an API key) or the reference frontends.
  3. The **Octra-side lock** tx format (how the ETH recipient is encoded) and
     the **claim proof** the light client expects.
- WalletConnect v2 integration for the external-wallet mode.
- UI: bridge sheet (mode selector, amount + EIP‑55 validation, gas preview,
  confirmation), Ethereum account view (ETH + wOCT balances), bridge history
  with a Claim action.

## Safety gates (mainnet money)

- Read wOCT `decimals()` on-chain before any amount conversion.
- EIP‑55 validate every ETH address; never log keys/seeds/signed payloads.
- Mandatory confirmation (direction, amount, recipient, fees) before signing.
- Verify claim eligibility on-chain (light client / bridge) before exposing
  the Claim action.
- First real wrap/unwrap must be tested with a **minimal** amount.
