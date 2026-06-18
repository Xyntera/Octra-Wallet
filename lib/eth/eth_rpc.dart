import 'dart:convert';

import 'package:http/http.dart' as http;

import 'eth_abi.dart';
import 'eth_constants.dart';

/// Minimal Ethereum JSON-RPC client for the reads the bridge needs: ETH/wOCT
/// balances, gas price, claim simulation (`eth_call`), and receipts.
///
/// Signing and sending transactions for the in-app *derived* account is handled
/// separately with web3dart; external (WalletConnect) signing is delegated to
/// the user's wallet. See docs/bridge-implementation.md.
class EthRpc {
  final String rpcUrl;
  final http.Client _client;

  EthRpc({String? rpcUrl, http.Client? client})
      : rpcUrl = rpcUrl ?? EthConstants.defaultRpcUrl,
        _client = client ?? http.Client();

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final res = await _client.post(
      Uri.parse(rpcUrl),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('eth $method: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw StateError('eth $method: ${jsonEncode(body['error'])}');
    }
    return body['result'];
  }

  static BigInt _hexToBig(String hex) => BigInt.parse(
        hex.startsWith('0x') ? hex.substring(2) : hex,
        radix: 16,
      );

  /// Native ETH balance in wei.
  Future<BigInt> ethBalanceWei(String address) async {
    final r = await _rpc('eth_getBalance', [address, 'latest']);
    return _hexToBig(r as String);
  }

  /// wOCT token balance (raw, 6 decimals) via ERC-20 `balanceOf`.
  Future<BigInt> woctBalance(String holder) async {
    final r = await _rpc('eth_call', [
      {'to': EthConstants.wOctToken, 'data': EthAbi.balanceOf(holder)},
      'latest',
    ]);
    final hex = r as String;
    if (hex == '0x' || hex.isEmpty) return BigInt.zero;
    return _hexToBig(hex);
  }

  /// Current chain id (1 == Ethereum mainnet).
  Future<int> chainId() async {
    final r = await _rpc('eth_chainId', []);
    return _hexToBig(r as String).toInt();
  }

  /// `eth_gasPrice` in wei.
  Future<BigInt> gasPrice() async {
    final r = await _rpc('eth_gasPrice', []);
    return _hexToBig(r as String);
  }

  /// Simulates a call (e.g. to check claim eligibility before sending). Returns
  /// the raw result hex; throws (with the revert reason) if the call reverts.
  Future<String> call(String to, String data, {String? from}) async {
    final tx = <String, dynamic>{'to': to, 'data': data};
    if (from != null) tx['from'] = from;
    final r = await _rpc('eth_call', [tx, 'latest']);
    return r as String;
  }

  /// Returns the receipt map, or null if the tx is not yet mined. Success is
  /// `status == '0x1'`.
  Future<Map<String, dynamic>?> transactionReceipt(String txHash) async {
    final r = await _rpc('eth_getTransactionReceipt', [txHash]);
    if (r == null) return null;
    return (r as Map).cast<String, dynamic>();
  }

  void dispose() => _client.close();
}
