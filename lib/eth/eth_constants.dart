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

  /// Recovery feed (keyed by lowercased ETH address) for recovering locks.
  static const String recoveryUrl =
      'https://relayer-002838819188.octra.network/recovery.json';

  /// Ethereum gas limits used by the reference for each bridge action.
  static const int claimGasLimit = 0x60000; // 393216
  static const int approveGasLimit = 0x30000; // 196608
  static const int burnGasLimit = 0x40000; // 262144

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
