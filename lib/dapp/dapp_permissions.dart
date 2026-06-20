import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// RFC-O-1 permission identifiers a dApp can request and the wallet enforces.
enum DappPermission {
  readAddress('read_address'),
  readBalance('read_balance'),
  readPublicKey('read_public_key'),
  signMessages('sign_messages'),
  sendTransactions('send_transactions'),
  contractCalls('contract_calls'),
  viewEncryptedBalance('view_encrypted_balance'),
  encryptBalance('encrypt_balance'),
  decryptBalance('decrypt_balance'),
  privateTransfers('private_transfers'),
  stealthScan('stealth_scan'),
  stealthClaim('stealth_claim');

  final String id;
  const DappPermission(this.id);

  static DappPermission? fromId(String id) {
    for (final p in DappPermission.values) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Short human label for approval UIs.
  String get label => switch (this) {
        DappPermission.readAddress => 'See your wallet address',
        DappPermission.readBalance => 'See your public balance',
        DappPermission.readPublicKey => 'See your public key',
        DappPermission.signMessages => 'Sign messages',
        DappPermission.sendTransactions => 'Request transactions (you approve each)',
        DappPermission.contractCalls => 'Read & call contracts',
        DappPermission.viewEncryptedBalance => 'View your private balance',
        DappPermission.encryptBalance => 'Encrypt balance (you approve)',
        DappPermission.decryptBalance => 'Decrypt balance (you approve)',
        DappPermission.privateTransfers => 'Private transfers (you approve)',
        DappPermission.stealthScan => 'Scan stealth payments',
        DappPermission.stealthClaim => 'Claim stealth payments (you approve)',
      };
}

/// Per-origin granted-permission store for the dApp browser. Grants are
/// persisted in [FlutterSecureStorage] under `dapp_perms_<origin>` and cached
/// in memory. A "connected" origin is simply one with a non-empty grant.
class DappPermissionStore extends ChangeNotifier {
  static const _prefix = 'dapp_perms_';

  final FlutterSecureStorage _storage;
  final Map<String, Set<String>> _cache = {};

  DappPermissionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Loads the grant for [origin] into the cache (idempotent).
  Future<Set<DappPermission>> load(String origin) async {
    if (!_cache.containsKey(origin)) {
      final raw = await _storage.read(key: '$_prefix$origin');
      final ids = <String>{};
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw);
          if (list is List) {
            for (final e in list) {
              ids.add(e.toString());
            }
          }
        } catch (_) {/* ignore corrupt grant */}
      }
      _cache[origin] = ids;
    }
    return granted(origin);
  }

  /// Currently granted permissions for [origin] (from cache).
  Set<DappPermission> granted(String origin) {
    final ids = _cache[origin] ?? const <String>{};
    return ids
        .map(DappPermission.fromId)
        .whereType<DappPermission>()
        .toSet();
  }

  bool isConnected(String origin) => (_cache[origin]?.isNotEmpty ?? false);

  bool has(String origin, DappPermission p) =>
      _cache[origin]?.contains(p.id) ?? false;

  /// Replaces the grant for [origin] with [perms] and persists it.
  Future<void> grant(String origin, Set<DappPermission> perms) async {
    final ids = perms.map((p) => p.id).toSet();
    _cache[origin] = ids;
    await _storage.write(
        key: '$_prefix$origin', value: jsonEncode(ids.toList()));
    notifyListeners();
  }

  /// Adds [perms] to the existing grant for [origin].
  Future<void> add(String origin, Set<DappPermission> perms) async {
    final ids = {..._cache[origin] ?? const <String>{}, ...perms.map((p) => p.id)};
    await grant(origin, ids.map(DappPermission.fromId).whereType<DappPermission>().toSet());
  }

  /// Clears the grant for [origin] (disconnect).
  Future<void> revoke(String origin) async {
    _cache.remove(origin);
    await _storage.delete(key: '$_prefix$origin');
    notifyListeners();
  }
}
