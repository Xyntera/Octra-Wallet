/// Verified mainnet parameters for the Octra <-> Ethereum (OCT <-> wOCT) bridge.
///
/// Addresses are taken from the official Octra docs
/// (docs.octra.org/oct-docs/contract-addresses) and Etherscan. They are pinned
/// here so the app never trusts a runtime-fetched address.
class EthConstants {
  EthConstants._();

  /// Ethereum mainnet chain id.
  static const int chainId = 1;

  /// Default public mainnet JSON-RPC endpoint (user-overridable in settings).
  /// Matches the official webcli bridge reference (static/bridge.js).
  static const String defaultRpcUrl = 'https://ethereum-rpc.publicnode.com';

  /// Wrapped OCT (wOCT) ERC-20 token.
  static const String wOctToken = '0x4647e1fE715c9e23959022C2416C71867F5a6E80';

  /// Ethereum-side bridge contract (mints wOCT on claim, burns on unwrap).
  static const String ethereumBridge =
      '0xE7eD69b852fd2a1406080B26A37e8E04e7dA4caE';

  /// On-chain Octra light client used to verify bridge headers/epochs.
  static const String octraLightClient =
      '0xC01cA57dc7f7C4B6f1B6b87B85D79e5ddf0dF55d';

  /// Octra-side bridge vault contract that locks OCT for wrapping. The lock is
  /// a normal Octra contract-call tx to this address (see [lockMethod]).
  static const String bridgeVault =
      'oct5MrNfjiXFNRDLwsodn8Zm9hDKNGAYt3eQDCQ52bSpCHq';

  /// Octra contract method invoked to lock OCT for the bridge. Carried in the
  /// tx `encrypted_data` field; the ETH recipient is `message=[ethAddress]`.
  static const String lockMethod = 'lock_to_eth';

  /// `ou` (gas) value used for the Octra lock tx, matching the webcli reference.
  static const String lockOu = '1000';

  /// Remote bridge signer/relayer. Produces Merkle proofs and the opaque
  /// Ethereum claim calldata, and drives the reverse-direction OCT release.
  static const String relayerUrl =
      'https://relayer-002838819188.octra.network';

  /// Recovery feed proxy used by the official bridge UI (bridge.0xio.xyz).
  /// Keyed as `{ by_recipient: { "0xlower...": [{epoch, leaf_index, amount_raw,
  /// src_nonce, message_id, tx_hash, found_at}] } }`.
  static const String recoveryUrl =
      'https://rpc-proxy.0xio.xyz/bridge/recovery.json';

  /// Ethereum gas limits used by the reference for each bridge action.
  static const int claimGasLimit = 0x60000; // 393216
  static const int approveGasLimit = 0x30000; // 196608
  static const int burnGasLimit = 0x40000; // 262144

  // ---- verifyAndMint (claim) message constants ----------------------------
  // Extracted from bridge.0xio.xyz source (static constants in the bundle).
  // These are hard-coded protocol values that identify the Octra<>Ethereum
  // bridge message format; they must match what the EthereumBridge contract
  // verifies on-chain.

  /// 4-byte selector for `verifyAndMint(uint64,(…),bytes32[],uint32)`.
  /// keccak256("verifyAndMint(uint64,(uint8,uint8,uint64,uint64,bytes32,bytes32,bytes32,address,uint128,uint64),bytes32[],uint32)")[:4]
  static const String verifyAndMintSelector = '5d5158ed';

  /// 4-byte selector for `latestEpoch()` on the OctraLightClient.
  static const String latestEpochSelector = '0x9cb118bf';

  static const int msgVersion = 1;
  static const int msgDirection = 0; // Octra → Ethereum
  static const int msgSrcChainId = 7777;
  static const int msgDstChainId = 1; // Ethereum mainnet

  static const String msgSrcBridgeId =
      '381ab73c25fb8d4ec4c03e15dd630fab75b410afd90a9276ab81df81c38d2a8b';
  static const String msgDstBridgeId =
      'ab33480ea300316d03f76278f05f08f011d41d60f5d49c6ff6d8489fbd60c794';

  /// wOCT token identifier used inside bridge messages (distinct from the
  /// wOCT ERC-20 address).
  static const String msgTokenId =
      '412ec1126381d672a9f42b8612e4bc9ee64f5b6467b991e61110203549cdd6de';

  /// BIP44 derivation path for the in-app Ethereum account (account 0).
  static const String ethDerivationPath = "m/44'/60'/0'/0/0";

  /// Minimum wrap amount enforced by the bridge (1 OCT, in micro-OCT).
  static const int minWrapMicroOct = 1000000;

  /// OCT decimals on Octra (micro-OCT).
  static const int octDecimals = 6;

  /// wOCT ERC-20 decimals. Confirmed from the official webcli bridge reference
  /// (static/bridge.js uses OCT_DECIMALS = 6 to format wOCT balances), i.e.
  /// wOCT mirrors OCT at 6 decimals — NOT the usual 18. Still verify against
  /// the token's on-chain `decimals()` at runtime before converting amounts.
  static const int wOctDecimals = 6;
}

/// Ethereum transaction speed tier controlling EIP-1559 fee multipliers.
enum GasSpeed {
  slow,
  standard,
  fast,
  rapid;

  String get label => switch (this) {
        slow => 'Slow',
        standard => 'Standard',
        fast => 'Fast',
        rapid => 'Rapid',
      };

  String get timing => switch (this) {
        slow => '~2–10 min',
        standard => '~30–60 sec',
        fast => '~15–30 sec',
        rapid => 'Next block',
      };

  /// Multiplier applied to current gas price (×10 to avoid floats).
  int get multiplierX10 => switch (this) {
        slow => 9,      // 0.9×
        standard => 12, // 1.2×
        fast => 15,     // 1.5×
        rapid => 20,    // 2.0×
      };

  /// Priority tip in gwei.
  int get priorityGwei => switch (this) {
        slow => 1,
        standard => 2,
        fast => 2,
        rapid => 3,
      };
}
