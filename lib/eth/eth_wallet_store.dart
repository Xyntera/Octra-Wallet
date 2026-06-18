import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'eth_account.dart';

/// Persists the user's Ethereum account for the bridge across the four modes
/// (create / import seed / import key / enter address / WalletConnect), and
/// rebuilds the runtime [EthAccount] on load.
///
/// Secrets (seed phrase / private key) live in [FlutterSecureStorage], separate
/// from the Octra wallet vault.
class EthWalletStore extends ChangeNotifier {
  static const _kMode = 'eth_acct_mode';
  static const _kSecret = 'eth_acct_secret'; // seed phrase or 0x-less priv key
  static const _kAddress = 'eth_acct_address'; // manual / walletConnect

  final FlutterSecureStorage _storage;

  EthAccount? account;

  /// Set transiently right after [createNew] so the UI can prompt a backup.
  /// Cleared once acknowledged.
  String? pendingBackupMnemonic;

  EthWalletStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  bool get hasAccount => account != null;

  Future<void> load() async {
    final mode = await _storage.read(key: _kMode);
    try {
      switch (mode) {
        case 'derived':
          final secret = await _storage.read(key: _kSecret);
          if (secret != null) account = EthAccount.fromMnemonic(secret);
          break;
        case 'imported':
          final secret = await _storage.read(key: _kSecret);
          if (secret != null) account = EthAccount.fromPrivateKey(secret);
          break;
        case 'manual':
          final addr = await _storage.read(key: _kAddress);
          if (addr != null) account = EthAccount.fromAddress(addr);
          break;
        case 'walletConnect':
          final addr = await _storage.read(key: _kAddress);
          if (addr != null) {
            account = EthAccount.fromAddress(addr,
                mode: EthAccountMode.walletConnect);
          }
          break;
      }
    } catch (_) {
      account = null;
    }
    notifyListeners();
  }

  /// Generates a fresh 12-word seed phrase, derives the account, and persists.
  /// The phrase is surfaced via [pendingBackupMnemonic] for the user to back up.
  Future<EthAccount> createNew() async {
    final mnemonic = bip39.generateMnemonic();
    final acc = EthAccount.fromMnemonic(mnemonic);
    await _storage.write(key: _kMode, value: 'derived');
    await _storage.write(key: _kSecret, value: mnemonic);
    await _storage.delete(key: _kAddress);
    account = acc;
    pendingBackupMnemonic = mnemonic;
    notifyListeners();
    return acc;
  }

  Future<EthAccount> importSeed(String phrase) async {
    final clean = phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(clean)) {
      throw ArgumentError('Invalid recovery phrase');
    }
    final acc = EthAccount.fromMnemonic(clean);
    await _storage.write(key: _kMode, value: 'derived');
    await _storage.write(key: _kSecret, value: clean);
    await _storage.delete(key: _kAddress);
    account = acc;
    pendingBackupMnemonic = null;
    notifyListeners();
    return acc;
  }

  Future<EthAccount> importPrivateKey(String hex) async {
    final acc = EthAccount.fromPrivateKey(hex); // validates
    final clean = hex.trim().replaceFirst(RegExp(r'^0[xX]'), '');
    await _storage.write(key: _kMode, value: 'imported');
    await _storage.write(key: _kSecret, value: clean);
    await _storage.delete(key: _kAddress);
    account = acc;
    pendingBackupMnemonic = null;
    notifyListeners();
    return acc;
  }

  Future<EthAccount> setManualAddress(String address) async {
    final acc = EthAccount.fromAddress(address); // validates
    await _storage.write(key: _kMode, value: 'manual');
    await _storage.write(key: _kAddress, value: acc.address);
    await _storage.delete(key: _kSecret);
    account = acc;
    pendingBackupMnemonic = null;
    notifyListeners();
    return acc;
  }

  /// Records a WalletConnect-paired external address (signing happens in the
  /// external wallet). The live session is held by the WalletConnect service.
  Future<EthAccount> setWalletConnect(String address) async {
    final acc =
        EthAccount.fromAddress(address, mode: EthAccountMode.walletConnect);
    await _storage.write(key: _kMode, value: 'walletConnect');
    await _storage.write(key: _kAddress, value: acc.address);
    await _storage.delete(key: _kSecret);
    account = acc;
    pendingBackupMnemonic = null;
    notifyListeners();
    return acc;
  }

  Future<void> clearAccount() async {
    await _storage.delete(key: _kMode);
    await _storage.delete(key: _kSecret);
    await _storage.delete(key: _kAddress);
    account = null;
    pendingBackupMnemonic = null;
    notifyListeners();
  }

  /// Reveals the stored seed phrase for backup (derived accounts only).
  Future<String?> revealSeedPhrase() async {
    final mode = await _storage.read(key: _kMode);
    if (mode != 'derived') return null;
    return _storage.read(key: _kSecret);
  }
}
