# OCT ↔ wOCT Bridge — Implementation Spec & Status

In-app Ethereum wallet + Octra↔Ethereum bridge so users can wrap native **OCT**
into **wOCT** (ERC‑20 on Ethereum mainnet) and unwrap it back, from inside Octra
Wallet.

**The bridge IS in `octra-labs/webcli`** — in `static/bridge.js` (+ `bridge.html`,
`swap.html`) and the `main.cpp` HTTP backend. This spec is extracted verbatim
from that reference. webcli runs a local C++ server that signs the Octra side and
proxies the relayer; our native app does the same work in-process (it already has
Octra signing) and calls the relayer directly.

## Constants (pinned in `lib/eth/eth_constants.dart`)

| Name | Value |
|---|---|
| Octra bridge vault | `oct5MrNfjiXFNRDLwsodn8Zm9hDKNGAYt3eQDCQ52bSpCHq` |
| wOCT ERC‑20 | `0x4647e1fE715c9e23959022C2416C71867F5a6E80` |
| EthereumBridge | `0xE7eD69b852fd2a1406080B26A37e8E04e7dA4caE` |
| Relayer/signer | `https://relayer-002838819188.octra.network` |
| Recovery feed | `…/recovery.json` (keyed by lowercased ETH address) |
| Eth RPC (default) | `https://ethereum-rpc.publicnode.com` |
| Chain id | `1` (mainnet) |
| OCT / wOCT decimals | `6` / `6` — 1:1, no scaling |
| Fee | `0` (only `ou="1000"` on the lock + Ethereum gas) |

## WRAP (OCT → wOCT)

1. **Lock on Octra** — a normal contract-call tx (no special envelope):
   `to_ = bridgeVault`, `amount = rawMicroOct`, `ou = "1000"`,
   `op_type = "call"`, `encrypted_data = "lock_to_eth"`,
   `message = jsonEncode([ethRecipient])` (the ETH address as a plain string).
   Sign with the existing Octra canonical order
   (`from,to_,amount,nonce,ou,timestamp,op_type,encrypted_data,message`) and
   submit via `RpcClient`. → `tx_hash`.
2. **Confirm** the lock via the contract receipt; read `epoch` from it.
3. **Relayer:** poll `bridgeHeader(epoch)` until `message_count > 0`, then
   `bridgeMessagesByEpoch(epoch)` → find the message whose `recipient` matches
   the ETH address → `bridgeClaimCalldata(epoch, leaf_index)` → **opaque
   calldata** (the client never builds the proof).
4. **Simulate** `eth_call(ETH_BRIDGE, calldata)` until it stops reverting (header
   landed on Ethereum).
5. **Claim** — `eth_sendTransaction{to: ETH_BRIDGE, data: calldata, gas:0x60000,
   EIP‑1559}` (derived key signs, or WalletConnect). Success = receipt
   `status==0x1`.

## UNWRAP (wOCT → OCT)

1. **approve** — `WOCT_ADDR`, `approve(0x095ea7b3)(spender=ETH_BRIDGE,
   amount=raw)`, gas `0x30000`.
2. **burn** — `ETH_BRIDGE`, `burn(string,uint256) = 0xe3e3aed0` with the Octra
   address as a Solidity **string** (raw `oct…` ASCII, length 47), gas `0x40000`.
3. **Release** — relayer-driven; no client tx. Poll OCT `public_balance` until it
   increases (≈ up to 180s).

## Ethereum calldata (all hand-rolled, in `lib/eth/eth_abi.dart`)

| Call | Selector | Encoding |
|---|---|---|
| `balanceOf(address)` | `0x70a08231` | left-pad address to 32 bytes |
| `approve(address,uint256)` | `0x095ea7b3` | spender word + exact amount word |
| `burn(string,uint256)` | `0xe3e3aed0` | offset `0x40` \| amount \| len \| ASCII(addr) padded |

Recognized claim revert selectors (diagnostics): `0xb5a78004` already-claimed
(treat as success), `0xa2ad39b9` header-not-on-chain-yet, `0xa4875a49`
mint-cap, `0x09bde339` invalid-proof.

Gas (EIP‑1559): `maxFeePerGas = max(2×eth_gasPrice, 10 gwei)`,
`maxPriorityFeePerGas = 2 gwei`.

## Status

**Implemented + CI-validated:**
- `lib/eth/eth_constants.dart` — all pinned addresses/params above.
- `lib/eth/eth_account.dart` — derived (mnemonic → m/44'/60'/0'/0/0) + manual
  modes, EIP‑55. Tested against a known vector.
- `lib/eth/eth_abi.dart` — `balanceOf`/`approve`/`burn` calldata. **Byte-exact
  unit tests** vs the reference.
- `lib/eth/eth_rpc.dart` — ETH/wOCT balances, gas, `eth_call` claim simulation,
  receipts (raw JSON-RPC reads).
- `lib/eth/bridge_relayer.dart` — `bridgeHeader` / `bridgeMessagesByEpoch` /
  `bridgeClaimCalldata` (+ recipient→calldata helper).

**Remaining integration (well-specified above; needs a Dart build + small-amount
mainnet test):**
- `WalletController` method to build/sign/submit the Octra **lock** tx (reuse
  `_canonicalTxJson`/`_signTxPayload`/`RpcClient`; fields exactly as in WRAP §1)
  and read the contract receipt `epoch`.
- Derived-mode Ethereum signing/sending (web3dart `sendTransaction`, EIP‑1559)
  for `approve`/`burn`/`claim`; WalletConnect path for external signing.
- `BridgeService` orchestrating wrap (lock→poll→relayer→simulate→claim) and
  unwrap (approve→burn→poll), with persisted bridge history + a Claim action.
- UI: bridge sheet (mode selector derived/WalletConnect/manual, amount + EIP‑55
  validation, gas preview, confirmation), Ethereum account view (ETH + wOCT).

## Safety gates (mainnet money)

- Verify `chainId == 1` and wOCT `decimals` (expect 6) before converting amounts.
- EIP‑55 validate every ETH address; Octra recipient must be `oct…`, length 47.
- Mandatory confirmation (direction, amount, recipient, fees) before signing.
- Simulate the claim (`eth_call`) before sending; treat `0xb5a78004` as
  already-claimed.
- Never log keys/seeds/signed payloads. First real wrap/unwrap with a **minimal**
  amount.
