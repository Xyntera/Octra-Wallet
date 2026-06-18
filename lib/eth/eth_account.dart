import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/web3dart.dart';

import 'eth_constants.dart';

/// How the app obtains the Ethereum key/recipient for bridge operations.
///
/// - [derived]: an in-app account derived from the wallet's BIP39 mnemonic; the
///   app holds the key and can sign ETH/bridge transactions.
/// - [walletConnect]: an external wallet (e.g. MetaMask) paired over
///   WalletConnect; the app never holds the key and the user signs externally.
/// - [manual]: a user-entered address used only as a destination (cannot sign).
enum EthAccountMode { derived, walletConnect, manual }

/// An Ethereum account usable by the bridge. Only [derived] accounts can sign;
/// [walletConnect] signs externally and [manual] is recipient-only.
class EthAccount {
  final EthAccountMode mode;

  /// EIP-55 checksummed address (0x...).
  final String address;

  /// Present only for [EthAccountMode.derived]; null otherwise.
  final EthPrivateKey? credentials;

  const EthAccount({
    required this.mode,
    required this.address,
    this.credentials,
  });

  /// True when this account can locally sign Ethereum transactions.
  bool get canSign => credentials != null;

  /// Derive the in-app Ethereum account from a BIP39 mnemonic using the
  /// standard path m/44'/60'/0'/0/0 (secp256k1 + Keccak-256 + EIP-55).
  factory EthAccount.fromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(EthConstants.ethDerivationPath);
    final priv = child.privateKey;
    if (priv == null) {
      throw StateError('Failed to derive Ethereum private key');
    }
    final creds = EthPrivateKey(Uint8List.fromList(priv));
    return EthAccount(
      mode: EthAccountMode.derived,
      address: creds.address.hexEip55,
      credentials: creds,
    );
  }

  /// A recipient-only account from a user-entered address. Throws
  /// [ArgumentError] if [input] is not a valid Ethereum address.
  factory EthAccount.fromAddress(String input) {
    final addr = EthereumAddress.fromHex(input.trim());
    return EthAccount(mode: EthAccountMode.manual, address: addr.hexEip55);
  }

  /// Validate an Ethereum address (accepts with/without EIP-55 checksum).
  static bool isValidAddress(String input) {
    try {
      EthereumAddress.fromHex(input.trim());
      return true;
    } catch (_) {
      return false;
    }
  }
}
