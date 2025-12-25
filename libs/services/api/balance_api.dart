import 'dart:convert';
import 'package:http/http.dart' as http;

class BalanceApi {
  static const baseUrl = 'https://ouqro.tech';

  static Future<Map<String, dynamic>> getBalance({
    required String address,
    required String rpcUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/balance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'rpc_url': rpcUrl,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('failed to fetch balance');
    }

    return jsonDecode(res.body);
  }
}
