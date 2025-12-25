import 'dart:convert';
import 'package:http/http.dart' as http;

class SendApi {
  static const baseUrl = 'https://ouqro.tech';

  static Future<Map<String, dynamic>> sendTx({
    required String from,
    required String to,
    required double amount,
    required int nonce,
    String? message,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': to,
        'amount': amount,
        'nonce': nonce,
        'message': message,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('transaction failed');
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> multiSend({
    required String from,
    required List<Map<String, dynamic>> recipients,
    required int nonce,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'recipients': recipients,
        'nonce': nonce,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('multi-send failed');
    }

    return jsonDecode(res.body);
  }
}
