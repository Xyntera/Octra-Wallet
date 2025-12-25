import 'dart:convert';
import 'package:http/http.dart' as http;

class TransactionApi {
  static const baseUrl = 'https://ouqro.tech';

  /// Called after /balance (hash list comes from balance response)
  static Future<Map<String, dynamic>> getTxDetails({
    required List<String> hashes,
    required String address,
    required String rpcUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tx-details'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hashes': hashes,
        'rpc_url': rpcUrl,
        'address': address,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('failed to fetch tx details');
    }

    return jsonDecode(res.body);
  }
}
