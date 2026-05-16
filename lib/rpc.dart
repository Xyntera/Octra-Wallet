import 'dart:convert';
import 'package:http/http.dart' as http;

const String kBaseUrl = 'http://46.101.86.250:8080';
const int kTimeoutSeconds = 10;
const int kMicro = 1000000;

class RpcClient {
  final String baseUrl;
  final http.Client _client;
  int _rpcId = 0;

  RpcClient({this.baseUrl = kBaseUrl}) : _client = http.Client();

  /// Basic Request
  Future<RpcResponse> req(String method, String path, {dynamic data}) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      http.Response response;
      final headers = {'Content-Type': 'application/json'};
      final body = data != null ? jsonEncode(data) : null;

      if (method.toUpperCase() == 'POST') {
        response = await _client
            .post(url, headers: headers, body: body)
            .timeout(Duration(seconds: kTimeoutSeconds));
      } else {
        response = await _client
            .get(url, headers: headers)
            .timeout(Duration(seconds: kTimeoutSeconds));
      }

      dynamic jsonBody;
      try {
        if (response.body.trim().isNotEmpty) {
          jsonBody = jsonDecode(response.body);
        }
      } catch (_) {
        jsonBody = null;
      }

      return RpcResponse(response.statusCode, response.body, jsonBody);
    } catch (e) {
      return RpcResponse(0, e.toString(), null);
    }
  }

  /// Private Request (Authentication via Header)
  Future<RpcResponse> reqPrivate(String path, String privateKey,
      {String method = 'GET', dynamic data}) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Private-Key': privateKey,
      };

      http.Response response;
      final body = data != null ? jsonEncode(data) : null;

      if (method.toUpperCase() == 'POST') {
        response = await _client
            .post(url, headers: headers, body: body)
            .timeout(Duration(seconds: kTimeoutSeconds));
      } else {
        response = await _client
            .get(url, headers: headers)
            .timeout(Duration(seconds: kTimeoutSeconds));
      }

      dynamic jsonBody;
      try {
        if (response.body.trim().isNotEmpty) {
          jsonBody = jsonDecode(response.body);
        }
      } catch (_) {
        jsonBody = {};
      }

      return RpcResponse(response.statusCode, response.body, jsonBody);
    } catch (e) {
      return RpcResponse(0, e.toString(), null);
    }
  }

  // --- Specific Methods ---

  Future<RpcResponse> rpcCall(
    String method,
    List<dynamic> params, {
    int timeoutSeconds = 30,
  }) async {
    final url = Uri.parse('$baseUrl/rpc');
    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': method,
              'params': params,
              'id': ++_rpcId,
            }),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      dynamic jsonBody;
      try {
        jsonBody =
            response.body.trim().isEmpty ? null : jsonDecode(response.body);
      } catch (_) {
        jsonBody = null;
      }

      if (jsonBody is Map && jsonBody.containsKey('error')) {
        return RpcResponse(response.statusCode, response.body, jsonBody);
      }
      return RpcResponse(response.statusCode, response.body, jsonBody);
    } catch (e) {
      return RpcResponse(0, e.toString(), null);
    }
  }

  dynamic rpcResult(RpcResponse response) {
    final body = response.json;
    if (body is Map && body.containsKey('result')) return body['result'];
    return null;
  }

  String? rpcError(RpcResponse response) {
    final body = response.json;
    if (body is Map && body['error'] != null) return body['error'].toString();
    if (response.statusCode == 0) return response.text;
    return null;
  }

  Future<Map<String, dynamic>?> getRecommendedFee(String operationType) async {
    final rpcRes = await rpcCall(
      'octra_recommendedFee',
      [operationType],
      timeoutSeconds: 10,
    );
    final body = rpcResult(rpcRes);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<Map<String, dynamic>> getBalanceAndNonce(String address) async {
    final rpcRes = await rpcCall('octra_balance', [address]);
    final rpcBody = rpcResult(rpcRes);
    if (rpcBody is Map) {
      return {
        "balance": double.tryParse(rpcBody['balance'].toString()) ?? 0.0,
        "nonce": int.tryParse(rpcBody['nonce'].toString()) ?? 0,
      };
    }

    // Mirrors cli.py st() logic
    // 1. Try /balance/{addr}
    final res = await req('GET', '/balance/$address');

    double balance = 0.0;
    int nonce = 0;

    if (res.statusCode == 200) {
      if (res.json != null) {
        balance = double.tryParse(res.json['balance'].toString()) ?? 0.0;
        nonce = int.tryParse(res.json['nonce'].toString()) ?? 0;
      } else if (res.text.isNotEmpty) {
        // Handle "100.000000 5" format
        final parts = res.text.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          balance = double.tryParse(parts[0]) ?? 0.0;
          nonce = int.tryParse(parts[1]) ?? 0;
        }
      }
    } else if (res.statusCode == 404) {
      // New account
      balance = 0.0;
      nonce = 0;
    }

    return {"balance": balance, "nonce": nonce};
  }

  Future<Map<String, dynamic>?> getAddressInfo(String address) async {
    final parts = address.split('?limit=');
    final addr = parts.first;
    final limit = parts.length > 1 ? int.tryParse(parts[1]) ?? 20 : 20;
    final rpcRes = await rpcCall('octra_account', [addr, limit]);
    final rpcBody = rpcResult(rpcRes);
    if (rpcBody is Map<String, dynamic>) {
      return rpcBody;
    }
    if (rpcBody is Map) {
      return Map<String, dynamic>.from(rpcBody);
    }

    final res = await req('GET', '/address/$address');
    if (res.statusCode == 200 && res.json != null) {
      return res.json;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTransactionsByAddress(
    String address, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rpcRes = await rpcCall(
      'octra_transactionsByAddress',
      [address, limit, offset],
      timeoutSeconds: 20,
    );
    final rpcBody = rpcResult(rpcRes);
    if (rpcBody is Map<String, dynamic>) return rpcBody;
    if (rpcBody is Map) return Map<String, dynamic>.from(rpcBody);
    return null;
  }

  Future<String?> getPublicKey(String address) async {
    final rpcRes = await rpcCall('octra_publicKey', [address]);
    final rpcBody = rpcResult(rpcRes);
    if (rpcBody is Map && rpcBody['public_key'] != null) {
      return rpcBody['public_key'].toString();
    }
    if (rpcBody is String) return rpcBody;

    final res = await req('GET', '/public_key/$address');
    if (res.statusCode == 200 && res.json != null) {
      return res.json['public_key'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEncryptedBalance(
      String address, String privateKey) async {
    final res =
        await reqPrivate('/view_encrypted_balance/$address', privateKey);
    if (res.statusCode == 200) {
      return res.json;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEncryptedBalanceRpc(
    String address,
    String signatureBase64,
    String publicKeyBase64,
  ) async {
    final res = await rpcCall(
      'octra_encryptedBalance',
      [address, signatureBase64, publicKeyBase64],
      timeoutSeconds: 30,
    );
    final body = rpcResult(res);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<Map<String, dynamic>?> getEncryptedCipherRpc(String address) async {
    final res =
        await rpcCall('octra_encryptedCipher', [address], timeoutSeconds: 30);
    final body = rpcResult(res);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<Map<String, dynamic>?> getPvacPubkeyRpc(String address) async {
    final res =
        await rpcCall('octra_pvacPubkey', [address], timeoutSeconds: 30);
    final body = rpcResult(res);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<List<dynamic>> getStealthOutputsRpc({int fromEpoch = 0}) async {
    final res =
        await rpcCall('octra_stealthOutputs', [fromEpoch], timeoutSeconds: 30);
    final body = rpcResult(res);
    if (body is Map && body['outputs'] is List) return body['outputs'] as List;
    if (body is List) return body;
    return const [];
  }

  Future<RpcResponse> registerPvacPubkeyRpc(
    String address,
    String pvacPubkeyBase64,
    String signatureBase64,
    String walletPublicKeyBase64,
    String aesKatHex,
  ) {
    return rpcCall(
      'octra_registerPvacPubkey',
      [
        address,
        pvacPubkeyBase64,
        signatureBase64,
        walletPublicKeyBase64,
        aesKatHex,
      ],
      timeoutSeconds: 30,
    );
  }

  Future<List<dynamic>> listContractsRpc() async {
    final res = await rpcCall('octra_listContracts', [], timeoutSeconds: 15);
    final body = rpcResult(res);
    if (body is Map && body['contracts'] is List)
      return body['contracts'] as List;
    if (body is List) return body;
    return const [];
  }

  Future<List<dynamic>> tokensByAddressRpc(String walletAddress) async {
    final res = await rpcCall('octra_tokensByAddress', [walletAddress],
        timeoutSeconds: 15);
    final body = rpcResult(res);
    if (body is Map && body['tokens'] is List) return body['tokens'] as List;
    if (body is List) return body;
    return const [];
  }

  Future<dynamic> contractStorageRpc(String address, String key) async {
    final res = await rpcCall('octra_contractStorage', [address, key],
        timeoutSeconds: 15);
    final body = rpcResult(res);
    if (body is Map && body.containsKey('value')) return body['value'];
    return null;
  }

  Future<dynamic> programStorageRpc(String address, String key) async {
    final res = await rpcCall('octra_programStorage', [address, key],
        timeoutSeconds: 15);
    final body = rpcResult(res);
    if (body is Map && body.containsKey('value')) return body['value'];
    return body;
  }

  Future<dynamic> contractCallViewRpc(
    String address,
    String method,
    List<dynamic> params,
    String caller,
  ) async {
    final res = await rpcCall(
      'contract_call',
      [address, method, params, caller],
      timeoutSeconds: 15,
    );
    final body = rpcResult(res);
    if (body is Map && body.containsKey('result')) return body['result'];
    return body;
  }

  Future<RpcResponse> encryptBalance(String address, double amount,
      String privateKey, String encryptedData) async {
    final data = {
      "address": address,
      "amount": (amount * kMicro).toInt().toString(),
      "private_key": privateKey,
      "encrypted_data": encryptedData,
    };
    return await req('POST', '/encrypt_balance', data: data);
  }

  Future<RpcResponse> decryptBalance(String address, double amount,
      String privateKey, String encryptedData) async {
    final data = {
      "address": address,
      "amount": (amount * kMicro).toInt().toString(),
      "private_key": privateKey,
      "encrypted_data": encryptedData,
    };
    return await req('POST', '/decrypt_balance', data: data);
  }

  Future<RpcResponse> createPrivateTransfer(String fromAddr, String toAddr,
      double amount, String fromPrivKey, String toPubKey) async {
    final data = {
      "from": fromAddr,
      "to": toAddr,
      "amount": (amount * kMicro).toInt().toString(),
      "from_private_key": fromPrivKey,
      "to_public_key": toPubKey
    };
    return await req('POST', '/private_transfer', data: data);
  }

  Future<List<dynamic>> getPendingPrivateTransfers(
      String address, String privateKey) async {
    final res = await reqPrivate(
        '/pending_private_transfers?address=$address', privateKey);
    if (res.statusCode == 200 && res.json != null) {
      return res.json['pending_transfers'] ?? [];
    }
    return [];
  }

  Future<RpcResponse> claimPrivateTransfer(
      String address, String privateKey, String transferId) async {
    final data = {
      "recipient_address": address,
      "private_key": privateKey,
      "transfer_id": transferId
    };
    return await req('POST', '/claim_private_transfer', data: data);
  }

  Future<RpcResponse> sendTransaction(Map<String, dynamic> tx) async {
    final rpcRes = await rpcCall('octra_submit', [tx], timeoutSeconds: 30);
    if (rpcRes.statusCode == 200 && rpcError(rpcRes) == null) {
      return rpcRes;
    }
    return await req('POST', '/send-tx', data: tx);
  }

  Future<Map<String, dynamic>> getStaging() async {
    final rpcRes = await rpcCall('staging_view', [], timeoutSeconds: 5);
    final body = rpcResult(rpcRes);
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);

    final res = await req('GET', '/staging?t=5'); // timeout 5s matches cli
    return res.json ?? {};
  }

  Future<RpcResponse> getTx(String hash) async {
    final rpcRes =
        await rpcCall('octra_transaction', [hash], timeoutSeconds: 30);
    if (rpcRes.statusCode == 200 && rpcError(rpcRes) == null) {
      return rpcRes;
    }
    return await req('GET', '/tx/$hash');
  }
}

class RpcResponse {
  final int statusCode;
  final String text;
  final dynamic json;

  RpcResponse(this.statusCode, this.text, this.json);
}
