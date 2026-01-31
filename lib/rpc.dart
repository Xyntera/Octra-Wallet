import 'dart:convert';
import 'package:http/http.dart' as http;

const String kBaseUrl = 'https://octra.network';
const int kTimeoutSeconds = 10;
const int kMicro = 1000000;

class RpcClient {
  final String baseUrl;
  final http.Client _client;

  RpcClient({this.baseUrl = kBaseUrl}) : _client = http.Client();

  /// Basic Request
  Future<RpcResponse> req(String method, String path, {dynamic data}) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      http.Response response;
      final headers = {'Content-Type': 'application/json'};
      final body = data != null ? jsonEncode(data) : null;

      if (method.toUpperCase() == 'POST') {
        response = await _client.post(url, headers: headers, body: body).timeout(Duration(seconds: kTimeoutSeconds));
      } else {
        response = await _client.get(url, headers: headers).timeout(Duration(seconds: kTimeoutSeconds));
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
  Future<RpcResponse> reqPrivate(String path, String privateKey, {String method = 'GET', dynamic data}) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Private-Key': privateKey,
      };
      
      http.Response response;
      final body = data != null ? jsonEncode(data) : null;

      if (method.toUpperCase() == 'POST') {
        response = await _client.post(url, headers: headers, body: body).timeout(Duration(seconds: kTimeoutSeconds));
      } else {
        response = await _client.get(url, headers: headers).timeout(Duration(seconds: kTimeoutSeconds));
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

  Future<Map<String, dynamic>> getBalanceAndNonce(String address) async {
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
    final res = await req('GET', '/address/$address');
    if (res.statusCode == 200 && res.json != null) {
      return res.json;
    }
    return null;
  }

  Future<String?> getPublicKey(String address) async {
    final res = await req('GET', '/public_key/$address');
    if (res.statusCode == 200 && res.json != null) {
      return res.json['public_key'];
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEncryptedBalance(String address, String privateKey) async {
    final res = await reqPrivate('/view_encrypted_balance/$address', privateKey);
    if (res.statusCode == 200) {
      return res.json;
    }
    return null;
  }

  Future<RpcResponse> encryptBalance(String address, double amount, String privateKey, String encryptedData) async {
    final data = {
      "address": address,
      "amount": (amount * kMicro).toInt().toString(),
      "private_key": privateKey,
      "encrypted_data": encryptedData,
    };
    return await req('POST', '/encrypt_balance', data: data);
  }

  Future<RpcResponse> decryptBalance(String address, double amount, String privateKey, String encryptedData) async {
     final data = {
      "address": address,
      "amount": (amount * kMicro).toInt().toString(),
      "private_key": privateKey,
      "encrypted_data": encryptedData,
    };
    return await req('POST', '/decrypt_balance', data: data);
  }

  Future<RpcResponse> createPrivateTransfer(String fromAddr, String toAddr, double amount, String fromPrivKey, String toPubKey) async {
    final data = {
      "from": fromAddr,
      "to": toAddr,
      "amount": (amount * kMicro).toInt().toString(),
      "from_private_key": fromPrivKey,
      "to_public_key": toPubKey
    };
    return await req('POST', '/private_transfer', data: data);
  }

  Future<List<dynamic>> getPendingPrivateTransfers(String address, String privateKey) async {
    final res = await reqPrivate('/pending_private_transfers?address=$address', privateKey);
    if (res.statusCode == 200 && res.json != null) {
      return res.json['pending_transfers'] ?? [];
    }
    return [];
  }

  Future<RpcResponse> claimPrivateTransfer(String address, String privateKey, String transferId) async {
    final data = {
      "recipient_address": address,
      "private_key": privateKey,
      "transfer_id": transferId
    };
    return await req('POST', '/claim_private_transfer', data: data);
  }

  Future<RpcResponse> sendTransaction(Map<String, dynamic> tx) async {
    return await req('POST', '/send-tx', data: tx);
  }

  Future<Map<String, dynamic>> getStaging() async {
    final res = await req('GET', '/staging?t=5'); // timeout 5s matches cli
    return res.json ?? {};
  }
  
  Future<RpcResponse> getTx(String hash) async {
    return await req('GET', '/tx/$hash');
  }
}

class RpcResponse {
  final int statusCode;
  final String text;
  final dynamic json;

  RpcResponse(this.statusCode, this.text, this.json);
}
