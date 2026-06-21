import 'dart:convert';

import 'package:http/http.dart' as http;

import 'eth_constants.dart';

/// Client for the Octra bridge signer/relayer JSON-RPC API
/// (relayer-002838819188.octra.network). The relayer builds the Merkle proofs
/// and the opaque Ethereum claim calldata, and drives the reverse-direction
/// OCT release. The webcli reference proxies these through its local server;
/// a native app calls the relayer directly.
class BridgeRelayer {
  final String baseUrl;
  final http.Client _client;

  BridgeRelayer({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? EthConstants.relayerUrl,
        _client = client ?? http.Client();

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final res = await _client.post(
      Uri.parse(baseUrl),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('relayer $method: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is Map && body['error'] != null) {
      throw StateError('relayer $method: ${jsonEncode(body['error'])}');
    }
    if (body is Map) return body['result'];
    throw StateError('relayer $method: unexpected response');
  }

  /// Number of bridge messages in [epoch]; > 0 means the header is available
  /// and a claim can be assembled.
  Future<int> bridgeHeaderMessageCount(String epoch) async {
    final result = await _rpc('bridgeHeader', [epoch]);
    if (result is Map && result['message_count'] is num) {
      return (result['message_count'] as num).toInt();
    }
    return 0;
  }

  /// All bridge messages for [epoch]; each entry has `recipient` and
  /// `leaf_index`.
  Future<List<Map<String, dynamic>>> bridgeMessagesByEpoch(String epoch) async {
    final result = await _rpc('bridgeMessagesByEpoch', [epoch]);
    final msgs =
        (result is Map ? result['messages'] : null) as List? ?? const [];
    return msgs.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// Opaque, fully-built Ethereum claim calldata for a (epoch, leaf) message.
  Future<String> bridgeClaimCalldata(String epoch, int leafIndex) async {
    final result = await _rpc('bridgeClaimCalldata', [epoch, leafIndex]);
    final calldata = result is Map ? result['calldata'] : null;
    if (calldata is String && calldata.startsWith('0x')) return calldata;
    throw StateError('relayer returned no claim calldata');
  }

  /// Finds the claim calldata for [ethRecipient] in [epoch], or null if the
  /// recipient does not yet have a message in that epoch.
  Future<String?> claimCalldataForRecipient(
    String epoch,
    String ethRecipient,
  ) async {
    final messages = await bridgeMessagesByEpoch(epoch);
    final target = ethRecipient.toLowerCase();
    for (final m in messages) {
      final recip = (m['recipient'] as String?)?.toLowerCase();
      final leaf = m['leaf_index'];
      if (recip == target && leaf is num) {
        return bridgeClaimCalldata(epoch, leaf.toInt());
      }
    }
    return null;
  }

  /// Fetches the recovery feed and returns lock entries for [ethAddress].
  ///
  /// The feed structure is:
  ///   `{ by_recipient: { "0xlower...": [{epoch, leaf_index, amount_raw,
  ///     src_nonce, message_id, tx_hash, found_at}] } }`
  ///
  /// Returns an empty list on network or parse error.
  Future<List<Map<String, dynamic>>> fetchRecovery(String ethAddress) async {
    try {
      final res = await _client.get(
        Uri.parse(EthConstants.recoveryUrl),
        headers: const {'accept': 'application/json'},
      );
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body);
      if (data is! Map) return const [];
      // The feed nests entries under `by_recipient`.
      final byRecipient = data['by_recipient'];
      if (byRecipient is! Map) return const [];
      final entries = byRecipient[ethAddress.toLowerCase()];
      if (entries is! List) return const [];
      return entries
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Scans the full recovery feed for an entry matching [lockTxHash] (with or
  /// without `0x` prefix). Returns the entry or null if not found.
  Future<Map<String, dynamic>?> findRecoveryByTxHash(
    String lockTxHash,
  ) async {
    try {
      final res = await _client.get(
        Uri.parse(EthConstants.recoveryUrl),
        headers: const {'accept': 'application/json'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final byRecipient = data['by_recipient'];
      if (byRecipient is! Map) return null;
      final normalised = lockTxHash.toLowerCase().replaceAll('0x', '');
      for (final entries in byRecipient.values) {
        if (entries is! List) continue;
        for (final e in entries) {
          if (e is! Map) continue;
          final th = (e['tx_hash'] as String? ?? '').toLowerCase();
          if (th == normalised) {
            return Map<String, dynamic>.from(e)
              ..['eth_address'] =
                  byRecipient.entries.firstWhere((kv) => kv.value == entries).key;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void dispose() => _client.close();
}
