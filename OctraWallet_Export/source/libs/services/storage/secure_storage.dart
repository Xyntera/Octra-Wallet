import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/wallet_model.dart';

class SecureWalletStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ouqro_wallet';

  static Future<void> save(WalletModel w) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'address': w.address,
        'private': w.privateKeyB64,
        'public': w.publicKeyB64,
        'mnemonic': w.mnemonic,
        'nonce': w.nonce,
      }),
    );
  }

  static Future<WalletModel?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final j = jsonDecode(raw);
    return WalletModel(
      address: j['address'],
      privateKeyB64: j['private'],
      publicKeyB64: j['public'],
      mnemonic: List<String>.from(j['mnemonic']),
      nonce: j['nonce'],
    );
  }

  static Future<void> clear() async => _storage.delete(key: _key);
}
