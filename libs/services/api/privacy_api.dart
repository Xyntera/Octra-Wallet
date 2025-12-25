import 'dart:convert';
import 'package:http/http.dart' as http;

class PrivacyApi {
  static const baseUrl = 'https://ouqro.tech';

  static Future<Map<String, dynamic>> encrypt({
    required String address,
    required double amount,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/encrypt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'amount': amount,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> decrypt({
    required String address,
    required double amount,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/decrypt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'amount': amount,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> privateSend({
    required String from,
    required String to,
    required double amount,
    required int nonce,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/private-send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': to,
        'amount': amount,
        'nonce': nonce,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> pending({
    required String address,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/pending-transfers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address}),
    );
    return jsonDecode(res.body);
  }
}
